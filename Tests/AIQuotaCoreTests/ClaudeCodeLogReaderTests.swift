import Foundation
import Testing
@testable import AIQuotaCore

/// `readAllEvents()` costumava reler o histórico inteiro (às vezes centenas de MB, espalhados
/// por centenas de arquivos) a cada refresh de 30s — a esmagadora maioria desses arquivos parada
/// há dias, sem chance de pertencer ao bloco de 5h atual. Isso sozinho gerava consumo alto de
/// CPU/energia com o app parado em background. Estes testes travam o filtro por data de
/// modificação que resolve isso.
@Suite("Leitor de logs do Claude Code (~/.claude/projects)")
struct ClaudeCodeLogReaderTests {
    private func makeProjectsDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-projects-\(UUID().uuidString)")
    }

    private func writeSessionFile(in dir: URL, name: String, modified: Date) {
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try! "irrelevante".write(to: url, atomically: true, encoding: .utf8)
        try! FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
    }

    // /tmp é um symlink pra /private/tmp no macOS, e o enumerator devolve o caminho já
    // resolvido — comparar pelo nome do arquivo evita depender de qual forma cada lado usa.
    private func names(_ urls: [URL]) -> Set<String> {
        Set(urls.map(\.lastPathComponent))
    }

    @Test("Arquivo tocado há mais tempo que a janela recente é ignorado")
    func staleFileIsSkipped() {
        let dir = makeProjectsDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let now = utcDate(2026, 9, 18, 12, 0)
        writeSessionFile(in: dir, name: "velho.jsonl", modified: now.addingTimeInterval(-48 * 3600))
        writeSessionFile(in: dir, name: "recente.jsonl", modified: now.addingTimeInterval(-60))

        let reader = ClaudeCodeLogReader(projectsDirectory: dir, recentWindow: 24 * 3600, now: { now })
        #expect(names(reader.findJSONLFiles()) == ["recente.jsonl"])
    }

    @Test("Arquivo dentro da janela recente é mantido")
    func recentFileIsKept() {
        let dir = makeProjectsDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let now = utcDate(2026, 9, 18, 12, 0)
        writeSessionFile(in: dir, name: "sessao.jsonl", modified: now.addingTimeInterval(-3600))

        let reader = ClaudeCodeLogReader(projectsDirectory: dir, recentWindow: 24 * 3600, now: { now })
        #expect(names(reader.findJSONLFiles()) == ["sessao.jsonl"])
    }
}
