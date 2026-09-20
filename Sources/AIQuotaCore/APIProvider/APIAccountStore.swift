import Foundation

/// Uma conta conectada por chave. Várias por provedor: duas chaves de OpenRouter são duas
/// contas, e o que as distingue é o rótulo que a pessoa deu.
public struct APIAccount: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let providerId: String
    /// Nome dado pela pessoa: "pessoal", "trabalho", "cliente X".
    public var label: String
    public var key: String

    public init(id: String = UUID().uuidString, providerId: String, label: String, key: String) {
        self.id = id
        self.providerId = providerId
        self.label = label
        self.key = key
    }

    /// A chave como a UI pode mostrar. Quem mascara é a apresentação — o dado guardado é
    /// sempre a chave inteira, senão não dá para autenticar.
    public var maskedKey: String {
        guard key.count > 10 else { return String(repeating: "•", count: max(key.count, 4)) }
        return "\(key.prefix(6))…\(key.suffix(4))"
    }
}

/// Onde as chaves ficam: `~/.config/ai-quota/accounts.json`, com permissão 0600.
///
/// Arquivo separado de `providers.json` de propósito. O `providers.json` é feito para a pessoa
/// abrir, editar à mão e até colar num chamado de suporte; chave de API não pode estar junto
/// de um arquivo com essa vocação.
public enum APIAccountStore {
    public static let defaultFile = ProvidersConfigStore.defaultDirectory
        .appendingPathComponent("accounts.json")

    public static func load(from url: URL = defaultFile) -> [APIAccount] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([APIAccount].self, from: data)) ?? []
    }

    /// Grava com 0600 ANTES de escrever o conteúdo: criar o arquivo com a permissão padrão e
    /// apertar depois deixa uma janela em que a chave esteve legível para todo mundo.
    @discardableResult
    public static func save(_ accounts: [APIAccount], to url: URL = defaultFile) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(accounts)

            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(
                    atPath: url.path,
                    contents: nil,
                    attributes: [.posixPermissions: 0o600]
                )
            }
            try data.write(to: url, options: .atomic)
            // `.atomic` troca o inode, então a permissão precisa ser reaplicada depois.
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
            return true
        } catch {
            return false
        }
    }

    public static func add(_ account: APIAccount, to url: URL = defaultFile) {
        var all = load(from: url)
        all.removeAll { $0.id == account.id }
        all.append(account)
        save(all, to: url)
    }

    public static func remove(id: String, from url: URL = defaultFile) {
        save(load(from: url).filter { $0.id != id }, to: url)
    }

    public static func accounts(for providerId: String, from url: URL = defaultFile) -> [APIAccount] {
        load(from: url).filter { $0.providerId == providerId }
    }
}
