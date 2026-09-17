import Foundation

/// Um evento de uso de tokens extraído de um log do Claude Code (linha "assistant" com `message.usage`).
public struct UsageEvent: Equatable, Sendable {
    public let timestamp: Date
    public let model: String
    public let sessionId: String
    public let messageId: String?
    public let requestId: String?

    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int
    public let cacheReadInputTokens: Int
    public let thinkingTokens: Int

    /// Parte de `cacheCreationInputTokens` escrita com TTL de 5 minutos.
    public let cacheCreation5mTokens: Int
    /// Parte de `cacheCreationInputTokens` escrita com TTL de 1 hora.
    public let cacheCreation1hTokens: Int

    public init(
        timestamp: Date,
        model: String,
        sessionId: String,
        messageId: String?,
        requestId: String?,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationInputTokens: Int,
        cacheReadInputTokens: Int,
        thinkingTokens: Int,
        cacheCreation5mTokens: Int,
        cacheCreation1hTokens: Int
    ) {
        self.timestamp = timestamp
        self.model = model
        self.sessionId = sessionId
        self.messageId = messageId
        self.requestId = requestId
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.thinkingTokens = thinkingTokens
        self.cacheCreation5mTokens = cacheCreation5mTokens
        self.cacheCreation1hTokens = cacheCreation1hTokens
    }

    /// Chave de deduplicação: mesma resposta pode aparecer em mais de um arquivo .jsonl
    /// (resume/fork de sessão copia o histórico anterior para o novo arquivo).
    /// Verificado empiricamente em ~/.claude/projects: `message.id` (nível `message`) e
    /// `requestId` (nível raiz da linha) juntos identificam o evento de forma estável;
    /// sozinho, `requestId` já costuma bastar, mas combinamos os dois por segurança.
    public var dedupKey: String? {
        guard let messageId, let requestId else { return nil }
        return messageId + "|" + requestId
    }

    public var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationInputTokens + cacheReadInputTokens
    }
}
