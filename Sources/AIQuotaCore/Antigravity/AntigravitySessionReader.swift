import Foundation

/// Extrai o que dá para saber do Antigravity sem inventar nada: quando cada sessão do CLI subiu, e
/// qual conta está logada.
struct AntigravitySessionReader {
    let home: URL

    private var logDirectory: URL { home.appendingPathComponent("log") }

    /// Uma "interação" por arquivo de log de sessão. O carimbo vem do próprio NOME do arquivo
    /// (`cli-20260919_033149.log`), que o CLI monta na hora em que sobe — mais confiável que o
    /// mtime, que qualquer cópia ou backup mexe.
    func readSessions() -> [AntigravitySession] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: logDirectory.path)) ?? []
        return names.compactMap { name in
            Self.timestamp(fromLogFileName: name).map(AntigravitySession.init(timestamp:))
        }
    }

    private static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        // O nome do arquivo é escrito na hora local da máquina, sem fuso — interpretá-lo em UTC
        // jogaria toda sessão para a janela errada.
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func timestamp(fromLogFileName name: String) -> Date? {
        guard name.hasPrefix("cli-"), name.hasSuffix(".log") else { return nil }
        let stamp = name.dropFirst("cli-".count).dropLast(".log".count)
        return fileNameFormatter.date(from: String(stamp))
    }

    /// O e-mail da conta, lido da linha que o próprio CLI escreve no log ao autenticar:
    /// `applyAuthResult: email=fulano@gmail.com, authMethod=consumer`. O token OAuth fica no mesmo
    /// diretório e **não é lido** — não há uso local para ele aqui.
    func readAccountEmail() -> String? {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: logDirectory.path)) ?? []
        let newest = names
            .filter { $0.hasPrefix("cli-") && $0.hasSuffix(".log") }
            .sorted()
            .reversed()

        // Do mais recente para trás: uma sessão que rodou deslogada não tem a linha, e aí a conta
        // ainda é a da sessão anterior.
        for name in newest {
            guard let content = try? String(contentsOf: logDirectory.appendingPathComponent(name), encoding: .utf8) else {
                continue
            }
            if let email = Self.email(inLogContent: content) { return email }
        }
        return nil
    }

    static func email(inLogContent content: String) -> String? {
        guard let range = content.range(of: "applyAuthResult: email=", options: .backwards) else { return nil }
        let rest = content[range.upperBound...]
        let email = rest.prefix { !$0.isWhitespace && $0 != "," }
        return email.isEmpty ? nil : String(email)
    }
}

struct AntigravitySession: TimestampedEvent {
    let timestamp: Date
}
