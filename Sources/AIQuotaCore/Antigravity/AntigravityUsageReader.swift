import Foundation

/// Cota REAL do Antigravity, obtida rodando o próprio CLI do usuário (`agy --print "/usage"`) e
/// lendo o que ele imprime — exatamente o que a pessoa faz à mão no terminal.
///
/// Por que assim, e não chamando o endpoint direto: o número da cota nunca é gravado em disco (o
/// CLI e a IDE só consultam o servidor e mostram na tela), e chamar o `retrieveUserQuotaSummary`
/// por conta própria exigiria o token OAuth do Antigravity — credencial de outro app, que este
/// projeto não extrai. Invocar o `agy` contorna as duas coisas: é a ferramenta do próprio usuário,
/// que já sabe se autenticar, e a saída em `--output-format json` é estável e fácil de parsear.
///
/// O `/usage` é um comando de cliente: não gasta cota nem dispara turno de modelo (o JSON volta com
/// `num_turns: 0` e `usage` zerado). Ainda assim é uma chamada de rede que leva alguns segundos,
/// então o resultado é cacheado no processo — o refresh de 30s não pode subir um binário de 190 MB
/// a cada volta.
public enum AntigravityUsageReader {
    /// Cota semanal muda devagar; um cache generoso evita rodar o `agy` toda hora sem defasar nada
    /// que importe.
    private static let cacheTTL: TimeInterval = 5 * 60
    /// Teto de tempo para o subprocesso: offline ou deslogado, ele não pode travar o refresh.
    private static let timeout: TimeInterval = 25

    private final class Cache: @unchecked Sendable {
        static let shared = Cache()
        private let lock = NSLock()
        private var limits: [OfficialLimitInfo]?
        private var fetchedAt: Date?

        func read(maxAge: TimeInterval, now: Date) -> [OfficialLimitInfo]?? {
            lock.lock(); defer { lock.unlock() }
            guard let fetchedAt, now.timeIntervalSince(fetchedAt) < maxAge else { return nil }
            return .some(limits)
        }

        func store(_ value: [OfficialLimitInfo]?, now: Date) {
            lock.lock(); defer { lock.unlock() }
            limits = value; fetchedAt = now
        }
    }

    /// `nil` quando não deu para obter a cota (CLI ausente, offline, deslogado, formato mudou) — aí
    /// quem chama cai para a contagem de sessões. `agyPath`/`runner` são injetáveis para teste.
    public static func read(
        agyPath: String? = nil,
        now: Date = Date(),
        runner: ((String) -> Data?)? = nil
    ) -> [OfficialLimitInfo]? {
        if let cached = Cache.shared.read(maxAge: cacheTTL, now: now) {
            return cached
        }
        let limits: [OfficialLimitInfo]?
        if let runner {
            limits = (resolveAgy(agyPath: agyPath)).flatMap { runner($0) }.flatMap(parse(_:))
        } else {
            limits = resolveAgy(agyPath: agyPath).flatMap(runUsage(agyPath:)).flatMap(parse(_:))
        }
        Cache.shared.store(limits, now: now)
        return limits
    }

    /// Onde o `agy` costuma estar. `Hyperion` chama o binário por esse nome; aqui procuramos nos
    /// lugares canônicos em vez de depender do PATH (um app de barra de menu herda um PATH mínimo).
    static func resolveAgy(agyPath: String?) -> String? {
        if let agyPath { return FileManager.default.isExecutableFile(atPath: agyPath) ? agyPath : nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/agy",
            "/usr/local/bin/agy",
            "/opt/homebrew/bin/agy"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func runUsage(agyPath: String) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: agyPath)
        process.arguments = ["--print", "/usage", "--output-format", "json", "--print-timeout", "20s"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        // Lê o pipe numa thread própria: sem isso, uma saída maior que o buffer do pipe (64 KB)
        // trava o processo, que trava o `waitUntilExit`, que trava o refresh.
        let box = OutputBox()
        let readingDone = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            box.data = pipe.fileHandleForReading.readDataToEndOfFile()
            readingDone.signal()
        }

        do { try process.run() } catch { return nil }

        // Mata o subprocesso se ele passar do teto — offline/deslogado ele poderia ficar pendurado.
        let deadline = DispatchTime.now() + timeout
        let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: deadline, execute: killer)
        process.waitUntilExit()
        killer.cancel()
        _ = readingDone.wait(timeout: deadline)
        return box.data
    }

    private final class OutputBox: @unchecked Sendable { var data: Data? }

    /// Do JSON do `agy`: `command.data.groups[].buckets[]`, cada bucket com `remaining_fraction`
    /// (0...1, quanto SOBRA) e `reset_time`. Convertemos para "usado %" (100 − sobra) porque é
    /// assim que todas as outras barras do app falam, e o nome do grupo vira o rótulo da janela.
    static func parse(_ data: Data) -> [OfficialLimitInfo]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let command = root["command"] as? [String: Any],
              let payload = command["data"] as? [String: Any],
              let groups = payload["groups"] as? [[String: Any]] else {
            return nil
        }

        // Só o grupo do Gemini interessa — é o modelo do Antigravity que o usuário usa; o grupo
        // "Claude and GPT models" é ignorado a pedido dele. O Antigravity só expõe janela semanal
        // (não há bucket de sessão/5h nos dados), então o rótulo é "Semanal", como nos outros.
        var limits: [OfficialLimitInfo] = []
        for group in groups {
            guard let name = group["name"] as? String, name.lowercased().contains("gemini") else { continue }
            let buckets = group["buckets"] as? [[String: Any]] ?? []
            for bucket in buckets {
                guard let remaining = (bucket["remaining_fraction"] as? NSNumber)?.doubleValue else { continue }
                let used = max(0, min(100, (1 - remaining) * 100))
                let resetsAt = (bucket["reset_time"] as? String).flatMap(ISO8601Parsing.date(from:))
                limits.append(OfficialLimitInfo(label: "Semanal", usedPercent: used, resetsAt: resetsAt))
            }
        }
        return limits.isEmpty ? nil : limits
    }

    /// "Gemini Models" → "Gemini", "Claude and GPT models" → "Claude/GPT". Rótulos curtos, porque a
    /// coluna da barra é estreita e o nome longo do grupo não cabe.
    static func shortLabel(forGroup name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("gemini") { return "Gemini" }
        if lower.contains("claude") || lower.contains("gpt") { return "Claude/GPT" }
        return name
    }
}
