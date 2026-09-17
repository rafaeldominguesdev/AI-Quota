import Foundation

/// Estrutura crua de uma linha de log do Claude Code (~/.claude/projects/**/*.jsonl),
/// confirmada em disco com `jq` em 2026-09-17. Apenas os campos usados são declarados;
/// tudo mais é ignorado pelo decoder.
///
/// Observação importante: existe um campo `model` no nível raiz da linha, mas ele vem
/// sempre `null` nas linhas "assistant" reais observadas — o modelo correto está em
/// `message.model`.
struct ClaudeCodeLogLine: Decodable {
    let type: String?
    let timestamp: String?
    let sessionId: String?
    let requestId: String?
    let message: MessagePayload?

    struct MessagePayload: Decodable {
        let model: String?
        let id: String?
        let usage: UsagePayload?
    }

    struct UsagePayload: Decodable {
        let input_tokens: Int?
        let output_tokens: Int?
        let cache_creation_input_tokens: Int?
        let cache_read_input_tokens: Int?
        let output_tokens_details: OutputTokensDetails?
        let cache_creation: CacheCreationPayload?
    }

    struct OutputTokensDetails: Decodable {
        let thinking_tokens: Int?
    }

    struct CacheCreationPayload: Decodable {
        let ephemeral_5m_input_tokens: Int?
        let ephemeral_1h_input_tokens: Int?
    }
}
