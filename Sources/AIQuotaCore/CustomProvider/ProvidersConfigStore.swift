import Foundation

/// The result of loading `providers.json`: which custom providers were valid, plus a message
/// for every entry that was ignored for being malformed (surfaced to the UI/CLI, never silently
/// dropped and never enough to crash the app).
public struct ProvidersConfigResult: Sendable {
    public let primaryProviderId: String?
    public let customProviders: [CustomLogProviderConfig]
    public let errors: [String]
}

public enum ProvidersConfigStore {
    public static let defaultDirectory = URL(
        fileURLWithPath: (NSString(string: "~/.config/ai-quota")).expandingTildeInPath
    )
    public static let defaultFile = defaultDirectory.appendingPathComponent("providers.json")

    /// Loads `providers.json`, creating it with the built-in defaults + a commented-out example
    /// on first run. Never throws: a missing/unreadable/malformed top-level file just yields an
    /// empty result (built-in providers still work fine on their own).
    public static func load(from url: URL = defaultFile) -> ProvidersConfigResult {
        ensureDefaultFileExists(at: url)

        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ProvidersConfigResult(primaryProviderId: nil, customProviders: [], errors: [])
        }

        let primaryProviderId = root["primaryProviderId"] as? String
        let rawCustomList = (root["custom"] as? [[String: Any]]) ?? []

        var configs: [CustomLogProviderConfig] = []
        var errors: [String] = []
        for raw in rawCustomList {
            switch CustomLogProviderConfig.parse(raw) {
            case .success(let config):
                if config.enabled {
                    configs.append(config)
                }
            case .failure(let message):
                errors.append(message)
            }
        }

        return ProvidersConfigResult(primaryProviderId: primaryProviderId, customProviders: configs, errors: errors)
    }

    public static func ensureDefaultFileExists(at url: URL = defaultFile) {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? defaultFileContents.write(to: url, atomically: true, encoding: .utf8)
    }

    static let defaultFileContents = """
    {
      "_comment": "Configuração de provedores do AI Quota. Os provedores embutidos (claude-code, codex, gemini, grok, cursor) já funcionam sem nada aqui. Use \\"custom\\" para adicionar outras IAs (GLM, Qwen, DeepSeek etc.) sem recompilar o app — edite este arquivo e rode o CLI de novo (ou reabra o app).",
      "primaryProviderId": "claude-code",
      "custom": [
        {
          "_comment": "Exemplo (desativado) de provedor customizado para o GLM. Copie este bloco, ajuste os campos ao formato real dos logs do seu CLI e mude \\"enabled\\" para true.",
          "id": "glm",
          "displayName": "GLM",
          "enabled": false,
          "logGlob": "~/.glm/sessions/**/*.jsonl",
          "timestampPath": "timestamp",
          "modelPath": "model",
          "inputTokensPath": "usage.input_tokens",
          "outputTokensPath": "usage.output_tokens",
          "totalTokensPath": "usage.total_tokens",
          "cumulative": false,
          "pricing": { "inputPer1M": 0.5, "outputPer1M": 1.5 }
        }
      ]
    }
    """
}
