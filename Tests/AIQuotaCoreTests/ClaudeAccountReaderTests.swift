import Foundation
import Testing
@testable import AIQuotaCore

/// O Claude Code só regrava `cachedUsageUtilization` em `~/.claude.json` quando o CLI roda de
/// novo. Se a pessoa passar um tempo sem abrir o `claude`, o `resets_at` fica no passado e o
/// percentual (às vezes 100%) fica congelado ali — sem estes testes, a leitura voltaria a
/// mostrar uma janela "crítica" que na real já resetou horas atrás.
@Suite("Cache de utilização do Claude Code (~/.claude.json)")
struct ClaudeAccountReaderTests {
    private func writeConfig(_ json: [String: Any]) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-account-reader-\(UUID().uuidString).json")
        let data = try! JSONSerialization.data(withJSONObject: json)
        try! data.write(to: url)
        return url
    }

    private func config(fiveHourResetsAt: String?, sevenDayResetsAt: String?) -> [String: Any] {
        func entry(resetsAt: String?) -> [String: Any] {
            var e: [String: Any] = ["utilization": 100]
            if let resetsAt { e["resets_at"] = resetsAt }
            return e
        }
        return [
            "oauthAccount": ["emailAddress": "user@example.com", "organizationType": "claude_max"],
            "cachedUsageUtilization": [
                "utilization": [
                    "five_hour": entry(resetsAt: fiveHourResetsAt),
                    "seven_day": entry(resetsAt: sevenDayResetsAt),
                ]
            ],
        ]
    }

    @Test("Janela com resets_at no passado é descartada, mesmo com utilization alto")
    func expiredWindowIsDropped() {
        let url = writeConfig(config(
            fiveHourResetsAt: "2026-09-17T21:00:00.000000+00:00", // no passado
            sevenDayResetsAt: "2026-09-24T06:00:00.000000+00:00" // no futuro
        ))
        defer { try? FileManager.default.removeItem(at: url) }

        let now = ISO8601Parsing.date(from: "2026-09-18T12:00:00Z")!
        let reader = ClaudeAccountReader(configFile: url, now: { now })
        let account = reader.read()

        #expect(account?.officialLimits.map(\.label) == ["semanal"])
    }

    @Test("Janela com resets_at no futuro continua aparecendo")
    func stillActiveWindowIsKept() {
        let url = writeConfig(config(
            fiveHourResetsAt: "2026-09-18T18:00:00.000000+00:00", // no futuro
            sevenDayResetsAt: "2026-09-24T06:00:00.000000+00:00"
        ))
        defer { try? FileManager.default.removeItem(at: url) }

        let now = ISO8601Parsing.date(from: "2026-09-18T12:00:00Z")!
        let reader = ClaudeAccountReader(configFile: url, now: { now })
        let account = reader.read()

        #expect(account?.officialLimits.map(\.label) == ["5h", "semanal"])
    }

    @Test("As duas janelas expiradas não deixam nenhum limite oficial")
    func bothWindowsExpiredYieldsNoOfficialLimits() {
        let url = writeConfig(config(
            fiveHourResetsAt: "2026-09-17T21:00:00.000000+00:00",
            sevenDayResetsAt: "2026-09-10T06:00:00.000000+00:00"
        ))
        defer { try? FileManager.default.removeItem(at: url) }

        let now = ISO8601Parsing.date(from: "2026-09-18T12:00:00Z")!
        let reader = ClaudeAccountReader(configFile: url, now: { now })
        let account = reader.read()

        #expect(account?.officialLimits.isEmpty == true)
    }
}

@Suite("Virada da janela de 5h do Claude Code")
struct ClaudeRolloverReconciliationTests {

    private let now = utcDate(2026, 9, 19, 5, 0)

    /// `resets_at` daqui a ~5h = janela que acabou de virar (começou 5 min atrás).
    private var freshWindowReset: Date {
        now.addingTimeInterval(UsageWindowBuilder.windowDuration - 5 * 60)
    }

    /// `resets_at` da janela ANTERIOR: a que fechou quando esta abriu.
    private var previousWindowReset: Date {
        freshWindowReset.addingTimeInterval(-UsageWindowBuilder.windowDuration)
    }

    /// Jornal em arquivo temporário — os testes nunca tocam o de verdade em Application Support.
    private func makeJournal() -> UsageObservationJournal {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("aiquota-teste-\(UUID().uuidString).json")
        return UsageObservationJournal(file: file)
    }

    /// Simula o refresh anterior, que fechou a janela passada em `percent`.
    private func seed(_ journal: UsageObservationJournal, percent: Double, label: String = "5h") {
        journal.record(
            UsageObservationJournal.Observation(lastResetsAt: previousWindowReset, lastPercent: percent),
            account: "claude-code",
            label: label
        )
    }

    private func reconcile(
        _ limits: [OfficialLimitInfo],
        events: [UsageEvent],
        journal: UsageObservationJournal
    ) -> [OfficialLimitInfo] {
        ClaudeCodeProvider.reconciledWithLocalUsage(
            limits, events: events, journal: journal, account: "claude-code", now: now
        )
    }

    @Test("Número repetido depois da virada, sem uso local: vira 0%")
    func frozenPercentAfterRolloverIsZeroed() {
        let journal = makeJournal()
        seed(journal, percent: 100)
        let limits = [
            OfficialLimitInfo(label: "5h", usedPercent: 100, resetsAt: freshWindowReset),
            OfficialLimitInfo(label: "semanal", usedPercent: 48, resetsAt: now.addingTimeInterval(5 * 86400))
        ]
        // Uso local só na janela ANTERIOR (1h antes da virada).
        let events = [makeEvent(timestamp: now.addingTimeInterval(-65 * 60))]

        let result = reconcile(limits, events: events, journal: journal)

        #expect(result[0].usedPercent == 0)
        #expect(result[0].resetsAt == freshWindowReset) // a hora de reset continua valendo
        #expect(result[1].usedPercent == 48) // a semanal não virou, não é mexida
    }

    @Test("A suspeita sobrevive ao tempo: 40 min depois ainda é 0%")
    func suspicionHasNoExpiry() {
        let journal = makeJournal()
        seed(journal, percent: 100)
        let limits = [OfficialLimitInfo(label: "5h", usedPercent: 100, resetsAt: freshWindowReset)]

        // 1º refresh flagra a leitura como resquício.
        _ = reconcile(limits, events: [], journal: journal)
        // Refreshes seguintes: o `resets_at` já não é "novo", então só o flag guardado sustenta a
        // desconfiança. Era exatamente aqui que a carência de 15 min estourava.
        let result = reconcile(limits, events: [], journal: journal)

        #expect(result[0].usedPercent == 0)
    }

    @Test("Assim que o endpoint publica outro número, a desconfiança acaba")
    func trustReturnsWhenThePercentMoves() {
        let journal = makeJournal()
        seed(journal, percent: 100)
        let stale = [OfficialLimitInfo(label: "5h", usedPercent: 100, resetsAt: freshWindowReset)]
        _ = reconcile(stale, events: [], journal: journal)

        let fresh = [OfficialLimitInfo(label: "5h", usedPercent: 7, resetsAt: freshWindowReset)]
        let result = reconcile(fresh, events: [], journal: journal)

        #expect(result[0].usedPercent == 7)
    }

    @Test("Uso local na janela nova confirma o percentual: não mexemos nele")
    func realUsageInTheNewWindowIsKept() {
        let journal = makeJournal()
        seed(journal, percent: 100)
        let limits = [OfficialLimitInfo(label: "5h", usedPercent: 100, resetsAt: freshWindowReset)]
        let events = [makeEvent(timestamp: now.addingTimeInterval(-60))]

        let result = reconcile(limits, events: events, journal: journal)
        #expect(result[0].usedPercent == 100)
    }

    @Test("Percentual diferente do da janela anterior é legítimo, mesmo recém-virado")
    func aDifferentPercentIsNeverTouched() {
        let journal = makeJournal()
        seed(journal, percent: 100)
        let limits = [OfficialLimitInfo(label: "5h", usedPercent: 92, resetsAt: freshWindowReset)]

        let result = reconcile(limits, events: [], journal: journal)
        #expect(result[0].usedPercent == 92)
    }

    @Test("Sem memória da janela anterior, o número oficial vale como veio")
    func firstEverReadingIsTrusted() {
        let limits = [OfficialLimitInfo(label: "5h", usedPercent: 100, resetsAt: freshWindowReset)]
        let result = reconcile(limits, events: [], journal: makeJournal())
        #expect(result[0].usedPercent == 100)
    }

    @Test("A janela semanal usa a mesma regra, sem código próprio")
    func theWeeklyWindowGetsTheSameTreatment() {
        let journal = makeJournal()
        let weeklyReset = now.addingTimeInterval(6 * 86400)
        journal.record(
            UsageObservationJournal.Observation(
                lastResetsAt: weeklyReset.addingTimeInterval(-7 * 86400), lastPercent: 88
            ),
            account: "claude-code",
            label: "semanal"
        )
        let limits = [OfficialLimitInfo(label: "semanal", usedPercent: 88, resetsAt: weeklyReset)]

        let result = reconcile(limits, events: [], journal: journal)
        #expect(result[0].usedPercent == 0)
    }
}

@Suite("Janela real ancorada no resets_at")
struct AuthoritativeWindowTests {

    private let now = utcDate(2026, 9, 19, 5, 0)

    @Test("Com resets_at oficial, a janela é [resets_at - 5h, resets_at) — não o bloco do log")
    func officialResetAnchorsTheWindow() {
        let resetsAt = now.addingTimeInterval(2 * 3600)
        let limits = [OfficialLimitInfo(label: "5h", usedPercent: 40, resetsAt: resetsAt)]
        // Primeiro evento local 20 min DEPOIS do início real da janela: o bloco inferido dos logs
        // começaria às 02:00 (hora cheia do evento), 20 min atrasado em relação à janela real.
        let events = [makeEvent(timestamp: resetsAt.addingTimeInterval(-5 * 3600 + 20 * 60))]

        let resolved = AuthoritativeWindow.resolve(officialLimits: limits, events: events, now: now)

        #expect(resolved?.isOfficial == true)
        #expect(resolved?.window.start == resetsAt.addingTimeInterval(-5 * 3600))
        #expect(resolved?.window.end == resetsAt)
    }

    @Test("Sem limite oficial, cai para a janela inferida dos logs")
    func fallsBackToTheInferredWindow() {
        let events = [makeEvent(timestamp: now.addingTimeInterval(-30 * 60))]
        let resolved = AuthoritativeWindow.resolve(officialLimits: [], events: events, now: now)
        #expect(resolved?.isOfficial == false)
    }

    @Test("A contagem inclui só os eventos dentro da janela real")
    func countsOnlyEventsInsideTheWindow() {
        let resetsAt = now.addingTimeInterval(2 * 3600)
        let window = UsageWindow(start: resetsAt.addingTimeInterval(-5 * 3600))
        let events = [
            makeEvent(timestamp: window.start.addingTimeInterval(-60)),   // janela anterior
            makeEvent(timestamp: window.start),                            // borda: entra
            makeEvent(timestamp: window.start.addingTimeInterval(3600)),   // dentro
            makeEvent(timestamp: window.end)                               // borda: fica de fora
        ]

        #expect(AuthoritativeWindow.events(events, in: window).count == 2)
    }

    @Test("Janela recém-virada conta zero token, e isso é medição e não heurística")
    func aFreshWindowCountsZero() {
        let resetsAt = now.addingTimeInterval(5 * 3600 - 5 * 60) // virou 5 min atrás
        let limits = [OfficialLimitInfo(label: "5h", usedPercent: 100, resetsAt: resetsAt)]
        let events = [makeEvent(timestamp: now.addingTimeInterval(-90 * 60))] // janela anterior

        let resolved = AuthoritativeWindow.resolve(officialLimits: limits, events: events, now: now)!
        #expect(AuthoritativeWindow.events(events, in: resolved.window).isEmpty)
    }
}
