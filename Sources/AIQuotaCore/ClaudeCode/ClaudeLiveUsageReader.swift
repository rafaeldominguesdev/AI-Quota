import Foundation

/// Busca o percentual de uso da assinatura direto no endpoint OAuth que o próprio `claude` CLI
/// usa (o mesmo que alimenta a tela "Limites de uso" em claude.ai) — em vez de depender só do
/// `cachedUsageUtilization` que o CLI grava em `~/.claude.json`, que fica parado sempre que a
/// pessoa passa um tempo sem rodar o `claude` (ver `ClaudeAccountReader`, que só descarta o
/// número velho; não tinha como *renovar* ele).
///
/// Endpoint não documentado — comunidade descobriu, formato pode mudar. Por isso o parse é
/// tolerante (várias chaves candidatas) e qualquer falha (sem token, offline, formato mudou)
/// devolve `nil` em silêncio: quem chama cai de volta pro cache local, que por sua vez cai pra
/// estimativa por custo. Nunca trava o refresh e nunca derruba o app.
public enum ClaudeLiveUsageReader {
    /// Cache em memória do PROCESSO (não do disco) — sobrevive a `ProviderRegistry()` ser
    /// recriado a cada refresh de 30s, que é exatamente o problema: sem isto, cada refresh bateria
    /// na rede de novo. Um percentual de uso não muda rápido o bastante pra justificar isso.
    private static let cacheTTL: TimeInterval = 180
    private static let requestTimeout: TimeInterval = 6

    private final class Cache: @unchecked Sendable {
        static let shared = Cache()
        private let lock = NSLock()
        private var entries: [String: (limits: [OfficialLimitInfo]?, fetchedAt: Date)] = [:]

        func read(key: String, maxAge: TimeInterval, now: Date) -> [OfficialLimitInfo]?? {
            lock.lock(); defer { lock.unlock() }
            guard let entry = entries[key], now.timeIntervalSince(entry.fetchedAt) < maxAge else { return nil }
            return .some(entry.limits)
        }

        func store(_ limits: [OfficialLimitInfo]?, key: String, now: Date) {
            lock.lock(); defer { lock.unlock() }
            entries[key] = (limits, now)
        }
    }

    /// `nil` quando não há nada de novo pra dizer (sem token, offline, endpoint mudou, ou o
    /// último fetch — com ou sem sucesso — ainda está dentro do TTL e não é hora de tentar de
    /// novo). Quem chama já sabe cair pro cache local nesse caso.
    ///
    /// `credentialsFile` é o `.credentials.json` da CONTA em questão (`~/.claude/.credentials.json`
    /// por padrão; uma conta extra descoberta por `MultiAccountDiscovery` tem o seu próprio,
    /// dentro da própria pasta `.claude-<algo>`). O cache é isolado por conta (chaveado pelo
    /// caminho do arquivo) — contas diferentes não pisam uma na outra. O fallback do keychain só
    /// serve a conta padrão: o item "Claude Code-credentials" não é isolado por pasta.
    public static func read(
        credentialsFile: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json"),
        now: Date = Date()
    ) -> [OfficialLimitInfo]? {
        let cacheKey = credentialsFile.path
        if let cached = Cache.shared.read(key: cacheKey, maxAge: cacheTTL, now: now) {
            return cached
        }
        let limits = fetchLive(credentialsFile: credentialsFile)
        Cache.shared.store(limits, key: cacheKey, now: now)
        return limits
    }

    private static func fetchLive(credentialsFile: URL) -> [OfficialLimitInfo]? {
        guard let token = readToken(credentialsFile: credentialsFile) else { return nil }
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return nil }

        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        guard let data = fetchSync(request), let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        guard root["error"] == nil else { return nil }

        let get: (Set<String>) -> [String: Any]? = { keys in
            for key in keys {
                if let value = root[key] as? [String: Any] { return value }
            }
            return nil
        }
        let fiveHour = get(["five_hour", "fiveHour", "session", "5h", "current_session"])
        let sevenDay = get(["seven_day", "sevenDay", "weekly", "7d", "seven_day_all_models", "all_models"])

        let limits = [
            fiveHour.flatMap { parseEntry($0, label: "5h") },
            sevenDay.flatMap { parseEntry($0, label: "semanal") },
        ].compactMap { $0 }
        return limits.isEmpty ? nil : limits
    }

    private static func parseEntry(_ entry: [String: Any], label: String) -> OfficialLimitInfo? {
        let percent: Double? = ["utilization", "used_percent", "usedPercent", "percentage", "percent"]
            .lazy.compactMap { (entry[$0] as? NSNumber)?.doubleValue }.first
        guard let percent else { return nil }
        // Alguns campos vêm 0...1, outros 0...100.
        let normalized = percent <= 1 ? percent * 100 : percent
        let resetsAt = ["resets_at", "resetsAt", "reset_at", "resetAt"]
            .lazy.compactMap { (entry[$0] as? String).flatMap(ISO8601Parsing.date(from:)) }.first
        return OfficialLimitInfo(label: label, usedPercent: normalized, resetsAt: resetsAt)
    }

    // MARK: - Token

    private static let defaultCredentialsFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/.credentials.json")

    /// 1) o `.credentials.json` da conta (Linux e alguns setups); 2) keychain do macOS, item
    /// "Claude Code-credentials" — o mesmo par que `claude` grava/lê. O keychain só é tentado
    /// pra conta PADRÃO: é um item global, não isolado por pasta, então usá-lo pra uma conta
    /// extra devolveria o token errado em vez de simplesmente "sem dado".
    private static func readToken(credentialsFile: URL) -> String? {
        if let data = try? Data(contentsOf: credentialsFile),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = (root["claudeAiOauth"] as? [String: Any])?["accessToken"] as? String {
            return token
        }
        guard credentialsFile == defaultCredentialsFile else { return nil }
        return readTokenFromKeychain()
    }

    private static func readTokenFromKeychain() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // silencia "item not found" no stderr
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let output, !output.isEmpty,
                  let data = output.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            return (root["claudeAiOauth"] as? [String: Any])?["accessToken"] as? String
        } catch {
            return nil
        }
    }

    // MARK: - Rede síncrona

    /// Caixa só pra atravessar o resultado da closure do `dataTask` (roda numa thread do
    /// URLSession) de volta pra thread que está esperando no semáforo — `@unchecked Sendable`
    /// porque o próprio semáforo já garante que só um lado mexe no valor por vez.
    private final class ResultBox: @unchecked Sendable {
        var data: Data?
    }

    /// `snapshot(config:)` do `QuotaProvider` é síncrono (chamado numa `Task.detached`, longe da
    /// main thread) — em vez de mudar essa assinatura pro projeto inteiro, a chamada de rede
    /// bloqueia essa thread de fundo com um semáforo, como o resto do core já faz com `Process`.
    private static func fetchSync(_ request: URLRequest) -> Data? {
        let box = ResultBox()
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            guard error == nil, let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return
            }
            box.data = data
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + requestTimeout + 1)
        return box.data
    }
}
