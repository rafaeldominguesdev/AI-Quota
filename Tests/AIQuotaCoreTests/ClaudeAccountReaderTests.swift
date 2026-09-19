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

    @Test("Janela recém-virada sem uso local: 100% do endpoint vira 0%")
    func staleHighPercentRightAfterRolloverIsZeroed() {
        let limits = [
            OfficialLimitInfo(label: "5h", usedPercent: 100, resetsAt: freshWindowReset),
            OfficialLimitInfo(label: "semanal", usedPercent: 48, resetsAt: now.addingTimeInterval(5 * 86400))
        ]
        // Uso local só na janela ANTERIOR (1h antes da virada).
        let events = [makeEvent(timestamp: now.addingTimeInterval(-65 * 60))]

        let result = ClaudeCodeProvider.reconciledWithLocalUsage(limits, events: events, now: now)

        #expect(result[0].usedPercent == 0)
        #expect(result[0].resetsAt == freshWindowReset) // a hora de reset continua valendo
        #expect(result[1].usedPercent == 48) // a semanal nunca é mexida
    }

    @Test("Uso local depois da virada confirma o percentual: não mexemos nele")
    func realUsageInTheNewWindowIsKept() {
        let limits = [OfficialLimitInfo(label: "5h", usedPercent: 100, resetsAt: freshWindowReset)]
        let events = [makeEvent(timestamp: now.addingTimeInterval(-60))]

        let result = ClaudeCodeProvider.reconciledWithLocalUsage(limits, events: events, now: now)
        #expect(result[0].usedPercent == 100)
    }

    @Test("Fora da carência da virada, o número oficial vale como veio")
    func percentIsTrustedOutsideTheGracePeriod() {
        // Janela começou 2h atrás: já passou muito da defasagem do endpoint.
        let reset = now.addingTimeInterval(3 * 3600)
        let limits = [OfficialLimitInfo(label: "5h", usedPercent: 100, resetsAt: reset)]

        let result = ClaudeCodeProvider.reconciledWithLocalUsage(limits, events: [], now: now)
        #expect(result[0].usedPercent == 100)
    }

    @Test("Percentual baixo não é tocado nem na virada")
    func lowPercentIsNeverTouched() {
        let limits = [OfficialLimitInfo(label: "5h", usedPercent: 2, resetsAt: freshWindowReset)]
        let result = ClaudeCodeProvider.reconciledWithLocalUsage(limits, events: [], now: now)
        #expect(result[0].usedPercent == 2)
    }
}
