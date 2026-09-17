import Testing
import Foundation
@testable import AIQuotaCore

@Suite("Config de provedores customizados")
struct CustomProviderConfigTests {

    @Test("Provedor customizado válido é aceito")
    func validConfigIsAccepted() {
        let raw: [String: Any] = [
            "id": "glm",
            "displayName": "GLM",
            "logGlob": "~/.glm/sessions/**/*.jsonl",
            "timestampPath": "timestamp",
            "modelPath": "model",
            "inputTokensPath": "usage.input_tokens",
            "outputTokensPath": "usage.output_tokens"
        ]

        switch CustomLogProviderConfig.parse(raw) {
        case .success(let config):
            #expect(config.id == "glm")
            #expect(config.displayName == "GLM")
            #expect(config.enabled == true) // default quando ausente
            #expect(config.cumulative == false) // default quando ausente
        case .failure(let message):
            Issue.record("esperava sucesso, veio erro: \(message)")
        }
    }

    @Test("Provedor sem \"id\" é rejeitado com mensagem, sem crashar")
    func missingIdIsRejected() {
        let raw: [String: Any] = [
            "displayName": "Sem ID",
            "logGlob": "~/.x/**/*.jsonl",
            "timestampPath": "timestamp"
        ]
        switch CustomLogProviderConfig.parse(raw) {
        case .success:
            Issue.record("esperava falha por falta de id")
        case .failure(let message):
            #expect(message.contains("id"))
        }
    }

    @Test("Provedor com pricing malformado é rejeitado")
    func malformedPricingIsRejected() {
        let raw: [String: Any] = [
            "id": "glm",
            "displayName": "GLM",
            "logGlob": "~/.glm/**/*.jsonl",
            "timestampPath": "timestamp",
            "pricing": ["inputPer1M": "não é número"]
        ]
        switch CustomLogProviderConfig.parse(raw) {
        case .success:
            Issue.record("esperava falha por pricing malformado")
        case .failure(let message):
            #expect(message.contains("glm"))
        }
    }

    @Test("Um provedor customizado malformado é ignorado, os outros continuam funcionando")
    func malformedEntryIsSkippedWithoutBreakingTheRest() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configURL = tempDir.appendingPathComponent("providers.json")
        let json = """
        {
          "primaryProviderId": "claude-code",
          "custom": [
            { "id": "bom", "displayName": "Bom", "logGlob": "~/.bom/**/*.jsonl", "timestampPath": "timestamp" },
            { "displayName": "Sem id, malformado", "logGlob": "~/.ruim/**/*.jsonl", "timestampPath": "timestamp" },
            { "id": "outro-bom", "displayName": "Outro Bom", "logGlob": "~/.outro/**/*.jsonl", "timestampPath": "timestamp" }
          ]
        }
        """
        try json.write(to: configURL, atomically: true, encoding: .utf8)

        let result = ProvidersConfigStore.load(from: configURL)

        #expect(result.customProviders.count == 2)
        #expect(result.customProviders.map(\.id).sorted() == ["bom", "outro-bom"])
        #expect(result.errors.count == 1)
    }

    @Test("Arquivo de config ausente é criado com os defaults (exemplo desativado, sem erros)")
    func missingConfigFileGetsDefaultsGenerated() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configURL = tempDir.appendingPathComponent("providers.json")
        // Não existe ainda — load() deve criar o arquivo padrão em vez de falhar.
        let result = ProvidersConfigStore.load(from: configURL)

        #expect(FileManager.default.fileExists(atPath: configURL.path))
        // O exemplo embutido (GLM) vem com "enabled": false, então não conta como provedor ativo.
        #expect(result.customProviders.isEmpty)
        #expect(result.errors.isEmpty)
    }

    @Test("JSON de config corrompido (não decodificável) não derruba nada")
    func corruptedConfigFileYieldsEmptyResult() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configURL = tempDir.appendingPathComponent("providers.json")
        try "{ isto não é json válido".write(to: configURL, atomically: true, encoding: .utf8)

        let result = ProvidersConfigStore.load(from: configURL)
        #expect(result.customProviders.isEmpty)
        #expect(result.errors.isEmpty)
    }
}
