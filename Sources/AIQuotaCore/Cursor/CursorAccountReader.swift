import Foundation

/// Identidade da conta Cursor, obtida rodando `cursor-agent about --format json` — o próprio CLI
/// já sabe se autenticar, então isto nunca toca em Keychain nem em token guardado em disco.
///
/// Não existe cota (%) em lugar nenhum daqui: nem `status`, nem `about`, nem qualquer flag do
/// `--help` do `cursor-agent` publicam um número de uso. Isto só confirma QUEM está logado e em
/// qual plano — o suficiente para o painel mostrar "CONECTADO" de verdade depois de um
/// `cursor-agent login`, mesmo sem barra de consumo.
public struct CursorAccountReader: Sendable {
    public struct Account: Equatable, Sendable {
        public let email: String?
        public let planLabel: String?
    }

    private static let cacheTTL: TimeInterval = 5 * 60
    private static let timeout: TimeInterval = 10

    private final class Cache: @unchecked Sendable {
        static let shared = Cache()
        private let lock = NSLock()
        private var account: Account?
        private var fetchedAt: Date?

        func read(maxAge: TimeInterval, now: Date) -> Account?? {
            lock.lock(); defer { lock.unlock() }
            guard let fetchedAt, now.timeIntervalSince(fetchedAt) < maxAge else { return nil }
            return .some(account)
        }

        func store(_ value: Account?, now: Date) {
            lock.lock(); defer { lock.unlock() }
            account = value; fetchedAt = now
        }
    }

    public init() {}

    public func read(cursorAgentPath: String? = nil, now: Date = Date()) -> Account? {
        if let cached = Self.Cache.shared.read(maxAge: Self.cacheTTL, now: now) {
            return cached
        }
        let account = Self.resolve(cursorAgentPath: cursorAgentPath).flatMap(Self.runAbout(path:)).flatMap(Self.parse(_:))
        Self.Cache.shared.store(account, now: now)
        return account
    }

    /// Um app de barra de menu herda um PATH mínimo — procura nos lugares canônicos, como
    /// `AntigravityUsageReader` faz para o `agy`.
    static func resolve(cursorAgentPath: String?) -> String? {
        if let cursorAgentPath { return FileManager.default.isExecutableFile(atPath: cursorAgentPath) ? cursorAgentPath : nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/cursor-agent",
            "/usr/local/bin/cursor-agent",
            "/opt/homebrew/bin/cursor-agent"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func runAbout(path: String) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["about", "--format", "json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        let box = OutputBox()
        let readingDone = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            box.data = pipe.fileHandleForReading.readDataToEndOfFile()
            readingDone.signal()
        }

        do { try process.run() } catch { return nil }

        let deadline = DispatchTime.now() + timeout
        let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: deadline, execute: killer)
        process.waitUntilExit()
        killer.cancel()
        _ = readingDone.wait(timeout: deadline)
        return box.data
    }

    private final class OutputBox: @unchecked Sendable { var data: Data? }

    static func parse(_ data: Data) -> Account? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let email = root["userEmail"] as? String else {
            return nil
        }
        let tier = (root["subscriptionTier"] as? String)?.lowercased()
        return Account(email: email, planLabel: tier)
    }
}
