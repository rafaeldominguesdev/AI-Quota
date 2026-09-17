import Foundation

/// Varre ~/.claude/projects/**/*.jsonl e extrai os eventos de uso de tokens.
public struct ClaudeCodeLogReader: Sendable {
    public let projectsDirectory: URL

    public init(
        projectsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    ) {
        self.projectsDirectory = projectsDirectory
    }

    /// Lê todos os arquivos .jsonl, decodifica as linhas com uso de tokens e deduplica.
    public func readAllEvents() -> [UsageEvent] {
        let files = findJSONLFiles()
        var rawEvents: [UsageEvent] = []
        for file in files {
            rawEvents.append(contentsOf: Self.parseFile(at: file))
        }
        return Self.deduplicate(rawEvents)
    }

    func findJSONLFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: projectsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            files.append(url)
        }
        return files
    }

    /// Lê um único arquivo linha a linha (sem carregar tudo na memória) e decodifica
    /// os eventos de uso. Linhas que não decodificam como JSON válido, ou que não são
    /// respostas "assistant" com `message.usage`, são ignoradas silenciosamente —
    /// arquivos reais têm linhas de outros tipos (attachments, snapshots de ambiente etc.)
    /// e ocasionalmente linhas corrompidas com caracteres de controle não escapados.
    static func parseFile(at url: URL) -> [UsageEvent] {
        guard let reader = FileLineReader(path: url.path) else { return [] }
        defer { reader.close() }

        var events: [UsageEvent] = []
        while let line = reader.nextLine() {
            guard let event = decodeLine(line) else { continue }
            events.append(event)
        }
        return events
    }

    // Date.ISO8601FormatStyle é um struct Sendable (ao contrário de ISO8601DateFormatter),
    // seguro para armazenar como `static let` sob concorrência estrita do Swift 6.
    private static let isoStrategyWithFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let isoStrategyWithoutFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: false)

    private static let decoder = JSONDecoder()

    /// Decodifica uma única linha .jsonl em um `UsageEvent`, ou `nil` se a linha não for
    /// JSON válido, não for do tipo "assistant" ou não tiver `message.usage`.
    static func decodeLine(_ line: String) -> UsageEvent? {
        guard !line.isEmpty, let data = line.data(using: .utf8) else { return nil }
        guard let raw = try? decoder.decode(ClaudeCodeLogLine.self, from: data) else { return nil }
        guard raw.type == "assistant" else { return nil }
        guard let usage = raw.message?.usage else { return nil }
        guard let model = raw.message?.model else { return nil }
        guard let timestampString = raw.timestamp else { return nil }
        guard let timestamp = (try? isoStrategyWithFraction.parse(timestampString))
            ?? (try? isoStrategyWithoutFraction.parse(timestampString)) else { return nil }

        let cacheCreationInputTokens = usage.cache_creation_input_tokens ?? 0
        let cacheCreation5m: Int
        let cacheCreation1h: Int
        if let c5 = usage.cache_creation?.ephemeral_5m_input_tokens,
           let c1 = usage.cache_creation?.ephemeral_1h_input_tokens {
            cacheCreation5m = c5
            cacheCreation1h = c1
        } else {
            // Sem breakdown de TTL disponível: assume tudo como cache de 5 minutos
            // (o TTL padrão/mais comum), marcado explicitamente aqui pois afeta o custo.
            cacheCreation5m = cacheCreationInputTokens
            cacheCreation1h = 0
        }

        return UsageEvent(
            timestamp: timestamp,
            model: model,
            sessionId: raw.sessionId ?? "desconhecida",
            messageId: raw.message?.id,
            requestId: raw.requestId,
            inputTokens: usage.input_tokens ?? 0,
            outputTokens: usage.output_tokens ?? 0,
            cacheCreationInputTokens: cacheCreationInputTokens,
            cacheReadInputTokens: usage.cache_read_input_tokens ?? 0,
            thinkingTokens: usage.output_tokens_details?.thinking_tokens ?? 0,
            cacheCreation5mTokens: cacheCreation5m,
            cacheCreation1hTokens: cacheCreation1h
        )
    }

    /// Remove eventos duplicados por `messageId + requestId`. Eventos sem essas chaves
    /// (não deveria acontecer em respostas "assistant" reais, mas por segurança) nunca
    /// são descartados por deduplicação.
    public static func deduplicate(_ events: [UsageEvent]) -> [UsageEvent] {
        var seen = Set<String>()
        var result: [UsageEvent] = []
        result.reserveCapacity(events.count)
        for event in events {
            if let key = event.dedupKey {
                if seen.contains(key) { continue }
                seen.insert(key)
            }
            result.append(event)
        }
        return result
    }
}
