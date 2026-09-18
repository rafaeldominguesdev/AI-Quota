import Testing
import Foundation
@testable import AIQuotaCore

@Suite("Descoberta de múltiplas contas")
struct MultiAccountDiscoveryTests {

    private func makeFakeHome() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    @Test("Pasta .codex-<algo> com auth.json vira conta descoberta")
    func codexSiblingDirectoryIsDiscovered() throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let accountDir = home.appendingPathComponent(".codex-trabalho")
        try FileManager.default.createDirectory(at: accountDir, withIntermediateDirectories: true)
        try "{}".write(to: accountDir.appendingPathComponent("auth.json"), atomically: true, encoding: .utf8)

        let found = MultiAccountDiscovery.discover(homeDirectory: home)

        #expect(found.count == 1)
        #expect(found.first?.kind == .codex)
        #expect(found.first?.label == "trabalho")
    }

    @Test("Pasta .claude-<algo> com .claude.json vira conta descoberta")
    func claudeSiblingDirectoryIsDiscovered() throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let accountDir = home.appendingPathComponent(".claude-pessoal")
        try FileManager.default.createDirectory(at: accountDir, withIntermediateDirectories: true)
        try "{}".write(to: accountDir.appendingPathComponent(".claude.json"), atomically: true, encoding: .utf8)

        let found = MultiAccountDiscovery.discover(homeDirectory: home)

        #expect(found.count == 1)
        #expect(found.first?.kind == .claudeCode)
        #expect(found.first?.label == "pessoal")
    }

    @Test("Pasta .codex-<algo> sem auth.json não conta como conta")
    func codexSiblingWithoutAuthFileIsIgnored() throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".codex-incompleto"),
            withIntermediateDirectories: true
        )

        #expect(MultiAccountDiscovery.discover(homeDirectory: home).isEmpty)
    }

    @Test("As pastas padrão .codex e .claude nunca viram conta extra")
    func defaultDirectoriesAreNeverTreatedAsExtraAccounts() throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let codexDir = home.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)
        try "{}".write(to: codexDir.appendingPathComponent("auth.json"), atomically: true, encoding: .utf8)

        let claudeDir = home.appendingPathComponent(".claude")
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        try "{}".write(to: claudeDir.appendingPathComponent(".claude.json"), atomically: true, encoding: .utf8)

        #expect(MultiAccountDiscovery.discover(homeDirectory: home).isEmpty)
    }
}
