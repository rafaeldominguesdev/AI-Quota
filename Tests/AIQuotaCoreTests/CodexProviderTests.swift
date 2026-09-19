import Testing
import Foundation
@testable import AIQuotaCore

@Suite("Codex")
struct CodexProviderTests {

    /// Synthetic `token_count` line shaped exactly like real ~/.codex/sessions files, with a
    /// tiny `last_token_usage` delta but an intentionally huge `total_token_usage` (mimicking a
    /// long real session where the cumulative counter reaches tens of millions of tokens).
    private func tokenCountLine(timestamp: String, lastTotal: Int, cumulativeTotal: Int) -> String {
        """
        {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":\(cumulativeTotal),"cached_input_tokens":0,"cache_write_input_tokens":0,"output_tokens":0,"reasoning_output_tokens":0,"total_tokens":\(cumulativeTotal)},"last_token_usage":{"input_tokens":\(lastTotal),"cached_input_tokens":0,"cache_write_input_tokens":0,"output_tokens":0,"reasoning_output_tokens":0,"total_tokens":\(lastTotal)},"model_context_window":258400},"rate_limits":null}}
        """
    }

    @Test("Soma dos deltas (last_token_usage), nunca do cumulativo (total_token_usage)")
    func sumsDeltasNotCumulative() {
        let lines = [
            tokenCountLine(timestamp: "2026-09-07T20:00:00.000Z", lastTotal: 1000, cumulativeTotal: 1000),
            tokenCountLine(timestamp: "2026-09-07T20:05:00.000Z", lastTotal: 2500, cumulativeTotal: 3500),
            tokenCountLine(timestamp: "2026-09-07T20:10:00.000Z", lastTotal: 1800, cumulativeTotal: 5300)
        ]

        let events = lines.compactMap { CodexSessionParser.decodeTokenEvent(fromLine: $0) }
        #expect(events.count == 3)

        let summedTotal = events.reduce(0) { $0 + $1.totalTokens }
        // Soma correta dos deltas: 1000 + 2500 + 1800 = 5300 (que por coincidência bate com o
        // cumulativo final aqui só porque os deltas foram desenhados pra somar exatamente isso;
        // o ponto do teste é que cada evento individual usa o delta, não o total_token_usage.
        #expect(summedTotal == 5300)
        #expect(events[0].totalTokens == 1000)
        #expect(events[1].totalTokens == 2500)
        #expect(events[2].totalTokens == 1800)

        // Nenhum evento individual deve carregar o valor cumulativo enorme.
        for event in events {
            #expect(event.totalTokens < 1_000_000)
        }
    }

    @Test("Cumulativo muito maior que a soma dos deltas não é usado por engano")
    func cumulativeIsNeverMistakenForTheSum() {
        // Sessão longa e realista: delta pequeno em cada turno, cumulativo passando de 1 milhão.
        let lines = (0..<5).map { index in
            tokenCountLine(
                timestamp: "2026-09-07T20:0\(index):00.000Z",
                lastTotal: 50_000,
                cumulativeTotal: 1_000_000 + index * 50_000
            )
        }
        let events = lines.compactMap { CodexSessionParser.decodeTokenEvent(fromLine: $0) }
        let summed = events.reduce(0) { $0 + $1.totalTokens }

        #expect(summed == 250_000) // 5 * 50_000
        #expect(summed < 1_000_000) // bem menor que o cumulativo final (1_200_000)
    }

    @Test("Decodifica rate_limits com primary preenchido")
    func decodesPopulatedRateLimits() {
        let line = """
        {"timestamp":"2026-09-05T23:46:22.342Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":39663,"cached_input_tokens":29568,"cache_write_input_tokens":0,"output_tokens":186,"reasoning_output_tokens":0,"total_tokens":39849},"last_token_usage":{"input_tokens":21842,"cached_input_tokens":17664,"cache_write_input_tokens":0,"output_tokens":174,"reasoning_output_tokens":0,"total_tokens":22016},"model_context_window":258400},"rate_limits":{"limit_id":"codex","limit_name":null,"primary":{"used_percent":11.0,"window_minutes":300,"resets_at":1788669903},"secondary":{"used_percent":2.0,"window_minutes":10080,"resets_at":1789256703},"credits":{"has_credits":false,"unlimited":false,"balance":"0"},"individual_limit":null,"spend_control_reached":null,"plan_type":"plus","rate_limit_reached_type":null}}}
        """

        let decoded = CodexSessionParser.decodeRateLimits(fromLine: line)
        #expect(decoded != nil)
        #expect(decoded?.limits.primary?.used_percent == 11.0)
        #expect(decoded?.limits.primary?.window_minutes == 300)
        #expect(decoded?.limits.primary?.resets_at == 1788669903)
        #expect(decoded?.limits.plan_type == "plus")

        let officialLimits = CodexProvider.officialLimits(from: decoded!.limits)
        #expect(officialLimits.count == 2)
        #expect(officialLimits[0].usedPercent == 11.0)
        #expect(officialLimits[0].resetsAt == Date(timeIntervalSince1970: 1788669903))
        #expect(officialLimits[1].usedPercent == 2.0)
        #expect(officialLimits[1].resetsAt == Date(timeIntervalSince1970: 1789256703))
    }

    @Test("rate_limits com primary e secondary nulos não vira limite oficial")
    func nullRateLimitsAreIgnored() {
        let line = """
        {"timestamp":"2026-09-06T00:34:36.214Z","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{"limit_id":"premium","limit_name":null,"primary":null,"secondary":null,"credits":{"has_credits":false,"unlimited":false,"balance":"0"},"individual_limit":null,"spend_control_reached":null,"plan_type":null,"rate_limit_reached_type":null}}}
        """
        #expect(CodexSessionParser.decodeRateLimits(fromLine: line) == nil)
    }

    @Test("Extrai o modelo de uma linha turn_context")
    func decodesModelFromTurnContext() {
        let line = """
        {"timestamp":"2026-09-07T23:53:08.751Z","type":"turn_context","payload":{"turn_id":"abc","model":"gpt-6-astra","effort":"high"}}
        """
        #expect(CodexSessionParser.decodeModel(fromLine: line)?.model == "gpt-6-astra")
    }

    @Test("Linhas de outros tipos (ex.: response_item) não viram evento de token")
    func ignoresUnrelatedLineTypes() {
        let line = """
        {"timestamp":"2026-09-07T23:53:08.751Z","type":"response_item","payload":{"type":"message","content":[]}}
        """
        #expect(CodexSessionParser.decodeTokenEvent(fromLine: line) == nil)
        #expect(CodexSessionParser.decodeModel(fromLine: line) == nil)
    }

    /// O caso que fazia o Codex desaparecer do painel: um dia sem rodar o CLI, então nenhuma
    /// sessão dentro da janela de uso — mas a cota SEMANAL reportada segue valendo, e é ela que
    /// tem de aparecer (antes o provider voltava `unavailable` e a UI filtrava a linha fora).
    @Test("Sessão mais velha que a janela de uso ainda entrega o limite semanal")
    func staleSessionStillReportsWeeklyLimit() throws {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let sessionTimestamp = "2026-09-18T04:38:13.893Z"
        let weeklyReset = Int(now.timeIntervalSince1970) + 2 * 24 * 3600
        let expiredFiveHourReset = Int(now.timeIntervalSince1970) - 3600

        let line = """
        {"timestamp":"\(sessionTimestamp)","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{"limit_id":"codex","primary":{"used_percent":12.0,"window_minutes":300,"resets_at":\(expiredFiveHourReset)},"secondary":{"used_percent":75.0,"window_minutes":10080,"resets_at":\(weeklyReset)},"plan_type":"plus"}}}
        """

        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("codex-stale-\(UUID().uuidString)")
        let sessions = root.appendingPathComponent("sessions/2026/09/18")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let file = sessions.appendingPathComponent("rollout.jsonl")
        try line.write(to: file, atomically: true, encoding: .utf8)
        // Tocado há 3 dias: fora da janela de uso (24h), dentro da janela de limites (8 dias).
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-3 * 24 * 3600)],
            ofItemAtPath: file.path
        )

        let provider = CodexProvider(
            sessionsDirectory: root.appendingPathComponent("sessions"),
            now: { now }
        )
        let snapshot = try provider.snapshot(config: .defaultConfig)

        #expect(snapshot.kind == .fullTokens)
        #expect(snapshot.planLabel == "plus")
        // As duas janelas aparecem. A de 5h já resetou sem uso novo depois, então vira 0% e sem
        // hora de reset (só volta a contar no próximo uso); a semanal segue no valor reportado.
        #expect(snapshot.officialLimits.count == 2)
        #expect(snapshot.officialLimits[0].label == "5h")
        #expect(snapshot.officialLimits[0].usedPercent == 0)
        #expect(snapshot.officialLimits[0].resetsAt == nil)
        #expect(snapshot.officialLimits[1].label == "semanal")
        #expect(snapshot.officialLimits[1].usedPercent == 75.0)
        #expect(snapshot.totalTokens == 0)
    }

    @Test("Sem nenhuma sessão na janela de limites, o Codex volta indisponível")
    func noSessionsAtAllIsUnavailable() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("codex-empty-\(UUID().uuidString)")
        let sessions = root.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = CodexProvider(sessionsDirectory: sessions)
        let snapshot = try provider.snapshot(config: .defaultConfig)

        #expect(snapshot.kind == .unavailable)
        #expect(snapshot.officialLimits.isEmpty)
    }
}
