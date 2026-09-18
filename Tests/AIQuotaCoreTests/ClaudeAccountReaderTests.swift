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
