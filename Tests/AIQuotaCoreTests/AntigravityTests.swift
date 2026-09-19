import Testing
import Foundation
@testable import AIQuotaCore

@Suite("Antigravity")
struct AntigravityTests {

    @Test("O carimbo da sessão sai do nome do arquivo de log")
    func parsesTimestampFromLogFileName() {
        let date = AntigravitySessionReader.timestamp(fromLogFileName: "cli-20260919_033149.log")
        #expect(date != nil)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date!)
        #expect(parts.year == 2026)
        #expect(parts.month == 9)
        #expect(parts.day == 19)
        #expect(parts.hour == 3)
        #expect(parts.minute == 31)
        #expect(parts.second == 49)
    }

    @Test("Arquivo que não é log de sessão é ignorado")
    func ignoresOtherFiles() {
        #expect(AntigravitySessionReader.timestamp(fromLogFileName: "cli.log") == nil)
        #expect(AntigravitySessionReader.timestamp(fromLogFileName: "history.jsonl") == nil)
        #expect(AntigravitySessionReader.timestamp(fromLogFileName: "cli-quebrado.log") == nil)
    }

    @Test("O e-mail sai da linha que o CLI escreve ao autenticar")
    func readsEmailFromAuthLine() {
        let log = """
        I0913 21:11:48.097566 236 quota_manager.go:36] doRefreshQuota: skipped (not logged in)
        I0913 21:11:48.119993 291 server_oauth.go:192] applyAuthResult: email=fulano@gmail.com, authMethod=consumer, quotaProject=
        I0913 21:11:48.869320 236 quota_manager.go:45] doRefreshQuota: starting reload (force=true)
        """
        #expect(AntigravitySessionReader.email(inLogContent: log) == "fulano@gmail.com")
    }

    @Test("Log de sessão deslogada não inventa e-mail")
    func noEmailWhenLoggedOut() {
        let log = "I0913 21:11:48.097566 236 quota_manager.go:36] doRefreshQuota: skipped (not logged in)"
        #expect(AntigravitySessionReader.email(inLogContent: log) == nil)
    }

    @Test("Sem o diretório do CLI, o provedor volta como não instalado")
    func unavailableWithoutTheCLI() throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("antigravity-inexistente-\(UUID().uuidString)")
        let snapshot = try AntigravityProvider(home: missing).snapshot(config: .defaultConfig)
        #expect(snapshot.isInstalled == false)
        #expect(snapshot.eventCount == 0)
    }

    @Test("Conta sessões do diretório de log, ignorando o resto")
    func countsSessionsFromLogDirectory() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("antigravity-\(UUID().uuidString)")
        let logs = home.appendingPathComponent("log")
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        for name in ["cli-20260919_033127.log", "cli-20260919_033149.log", "history.jsonl"] {
            try "conteúdo".write(to: logs.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }

        let sessions = AntigravitySessionReader(home: home).readSessions()
        #expect(sessions.count == 2)
    }
}

@Suite("Antigravity — cota real via agy")
struct AntigravityUsageTests {

    /// A saída real do `agy --print "/usage" --output-format json`, capturada da máquina do usuário.
    private let realJSON = """
    {"conversation_id":"","status":"SUCCESS","response":"...","command":{"name":"usage","data":{"groups":[{"name":"Gemini Models","buckets":[{"id":"gemini-weekly","window":"weekly","remaining_fraction":0.9570896029472351,"reset_time":"2026-09-26T12:04:54Z"}]},{"name":"Claude and GPT models","buckets":[{"id":"3p-weekly","window":"weekly","remaining_fraction":0.9610120058059692,"reset_time":"2026-09-26T11:55:19Z"}]}]}}}
    """

    @Test("Só o grupo Gemini, como janela Semanal, convertendo sobra em usado")
    func parsesGeminiWeeklyOnly() throws {
        let limits = try #require(AntigravityUsageReader.parse(Data(realJSON.utf8)))
        // Só o Gemini — o grupo "Claude and GPT models" é ignorado de propósito.
        #expect(limits.count == 1)

        let semanal = try #require(limits.first)
        #expect(semanal.label == "Semanal")
        // 95.71% sobrando → ~4.29% usado.
        #expect(abs(semanal.usedPercent - 4.29) < 0.1)
        #expect(semanal.resetsAt != nil)
    }

    @Test("JSON sem grupos devolve nil, para cair no fallback")
    func nilWhenNoGroups() {
        #expect(AntigravityUsageReader.parse(Data("{}".utf8)) == nil)
        #expect(AntigravityUsageReader.parse(Data("não é json".utf8)) == nil)
    }

    @Test("agy inexistente resolve para nil sem rodar nada")
    func missingAgyResolvesNil() {
        #expect(AntigravityUsageReader.resolveAgy(agyPath: "/caminho/que/nao/existe/agy") == nil)
    }
}
