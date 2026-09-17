import Foundation

/// Resultado da checagem de disponibilidade de dados do Codex.
public enum CodexAvailability: Equatable, Sendable {
    /// Diretório não encontrado.
    case unavailable(reason: String)
    /// Diretório encontrado, mas o formato de dados de uso não está documentado
    /// (ver docs/DATA-SOURCES.md) — não inventamos parsing sem confirmar o formato real.
    case foundButFormatUndocumented(path: String)
}

/// Stub: docs/DATA-SOURCES.md não encontrou ~/.codex na máquina de referência usada para
/// mapear as fontes de dados, então não há formato documentado para extrair uso do Codex.
/// Esta implementação apenas checa a presença do diretório, sem inventar um parser.
/// Uma futura missão pode implementar a leitura real se/quando o formato for documentado.
public struct CodexUsageReader: Sendable {
    public let codexDirectory: String

    public init(codexDirectory: String = (NSString(string: "~/.codex")).expandingTildeInPath) {
        self.codexDirectory = codexDirectory
    }

    public func checkAvailability() -> CodexAvailability {
        guard FileManager.default.fileExists(atPath: codexDirectory) else {
            return .unavailable(reason: "Diretório ~/.codex não encontrado")
        }
        return .foundButFormatUndocumented(path: codexDirectory)
    }
}
