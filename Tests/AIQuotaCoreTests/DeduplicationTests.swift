import Testing
import Foundation
@testable import AIQuotaCore

@Suite("Deduplicação de eventos")
struct DeduplicationTests {

    @Test("Eventos com o mesmo messageId+requestId são deduplicados")
    func duplicateEventsAreRemoved() {
        let timestamp = utcDate(2026, 9, 17, 10, 0)
        let original = makeEvent(timestamp: timestamp, messageId: "msg_1", requestId: "req_1", inputTokens: 100)
        // Mesma resposta reaparecendo em outro arquivo (resume/fork de sessão).
        let duplicate = makeEvent(timestamp: timestamp, messageId: "msg_1", requestId: "req_1", inputTokens: 100)

        let result = ClaudeCodeLogReader.deduplicate([original, duplicate])

        #expect(result.count == 1)
    }

    @Test("Eventos com chaves diferentes são mantidos")
    func distinctEventsAreKept() {
        let events = [
            makeEvent(timestamp: utcDate(2026, 9, 17, 10, 0), messageId: "msg_1", requestId: "req_1"),
            makeEvent(timestamp: utcDate(2026, 9, 17, 10, 5), messageId: "msg_2", requestId: "req_2")
        ]
        let result = ClaudeCodeLogReader.deduplicate(events)
        #expect(result.count == 2)
    }

    @Test("Eventos sem messageId ou requestId nunca são descartados pela deduplicação")
    func eventsWithoutKeysAreNeverDeduplicated() {
        let events = [
            makeEvent(timestamp: utcDate(2026, 9, 17, 10, 0), messageId: nil, requestId: nil),
            makeEvent(timestamp: utcDate(2026, 9, 17, 10, 5), messageId: nil, requestId: nil)
        ]
        let result = ClaudeCodeLogReader.deduplicate(events)
        #expect(result.count == 2)
    }

    @Test("Decodifica uma linha .jsonl real e ignora linhas inválidas ou sem usage")
    func decodesValidLineAndSkipsInvalidOnes() {
        let validLine = """
        {"type":"assistant","timestamp":"2026-09-17T16:39:27.573Z","sessionId":"abc-123","requestId":"req_abc","message":{"model":"claude-opus-5","id":"msg_abc","usage":{"input_tokens":2,"cache_creation_input_tokens":100,"cache_read_input_tokens":50,"output_tokens":10,"output_tokens_details":{"thinking_tokens":3},"cache_creation":{"ephemeral_1h_input_tokens":80,"ephemeral_5m_input_tokens":20}}}}
        """
        let event = ClaudeCodeLogReader.decodeLine(validLine)
        #expect(event != nil)
        #expect(event?.model == "claude-opus-5")
        #expect(event?.inputTokens == 2)
        #expect(event?.cacheCreation1hTokens == 80)
        #expect(event?.cacheCreation5mTokens == 20)
        #expect(event?.thinkingTokens == 3)
        #expect(event?.dedupKey == "msg_abc|req_abc")

        // JSON quebrado (caractere de controle não escapado, como visto em logs reais).
        let brokenLine = "{\"type\":\"assistant\", \"timestamp\": \"broken\u{0001}\"}"
        #expect(ClaudeCodeLogReader.decodeLine(brokenLine) == nil)

        // Linha válida mas sem usage (ex.: eventos de outro tipo, como "attachment").
        let noUsageLine = """
        {"type":"attachment","timestamp":"2026-09-17T16:39:27.573Z"}
        """
        #expect(ClaudeCodeLogReader.decodeLine(noUsageLine) == nil)
    }
}
