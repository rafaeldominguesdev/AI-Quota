import Foundation

/// Descobre contas extras do Codex e do Claude Code — para quem roda mais de uma conta ao mesmo
/// tempo apontando `CODEX_HOME`/`CLAUDE_CONFIG_DIR` de cada terminal para uma pasta diferente.
///
/// IMPORTANTE — isto é heurística, não API documentada: `CODEX_HOME` é confirmado lendo o
/// binário do Codex (`$CODEX_HOME/config.toml`, "normally ~/.codex/config.toml"). Já
/// `CLAUDE_CONFIG_DIR` só foi confirmado como "a home da configuração" — não achei confirmação
/// de que o arquivo de conta (`.claude.json`) migra pra dentro dele junto com `projects/`. Por
/// isso a convenção adotada aqui (pasta em `$HOME` começando com `.codex`/`.claude`, contendo
/// `auth.json`/`.claude.json` no mesmo formato do diretório padrão) é o melhor palpite, não uma
/// garantia. Se uma segunda conta de verdade não aparecer, é esse o primeiro lugar a revisar.
public enum MultiAccountDiscovery {
    public struct DiscoveredAccount: Sendable, Equatable {
        public enum Kind: Sendable {
            case codex
            case claudeCode
        }

        public let kind: Kind
        public let directory: URL

        /// O pedaço do nome da pasta que não é o prefixo do provedor — ".codex-work" → "work",
        /// pra virar o rótulo da conta na UI.
        public var label: String {
            let prefix = kind == .codex ? ".codex" : ".claude"
            let trimmed = directory.lastPathComponent.dropFirst(prefix.count)
            let cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
            return cleaned.isEmpty ? directory.lastPathComponent : cleaned
        }
    }

    public static func discover(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [DiscoveredAccount] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: homeDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return []
        }

        var discovered: [DiscoveredAccount] = []
        for entry in entries {
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            let name = entry.lastPathComponent

            if name.hasPrefix(".codex"), name != ".codex" {
                let authFile = entry.appendingPathComponent("auth.json")
                if FileManager.default.fileExists(atPath: authFile.path) {
                    discovered.append(DiscoveredAccount(kind: .codex, directory: entry))
                }
            } else if name.hasPrefix(".claude"), name != ".claude" {
                let accountFile = entry.appendingPathComponent(".claude.json")
                if FileManager.default.fileExists(atPath: accountFile.path) {
                    discovered.append(DiscoveredAccount(kind: .claudeCode, directory: entry))
                }
            }
        }
        return discovered.sorted { $0.directory.lastPathComponent < $1.directory.lastPathComponent }
    }
}
