import Testing
import Foundation
@testable import AIQuotaCore

@Suite("Contas por chave de API")
struct APIAccountStoreTests {
    private func arquivoTemporario() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("accounts-\(UUID().uuidString).json")
    }

    @Test("guarda várias contas do mesmo provedor")
    func variasContas() throws {
        let f = arquivoTemporario()
        defer { try? FileManager.default.removeItem(at: f) }

        APIAccountStore.add(.init(providerId: "openrouter", label: "pessoal", key: "sk-or-1"), to: f)
        APIAccountStore.add(.init(providerId: "openrouter", label: "trabalho", key: "sk-or-2"), to: f)
        APIAccountStore.add(.init(providerId: "deepseek", label: "pessoal", key: "sk-d"), to: f)

        #expect(APIAccountStore.accounts(for: "openrouter", from: f).count == 2)
        #expect(APIAccountStore.accounts(for: "deepseek", from: f).count == 1)
    }

    /// O arquivo guarda chave de API: se nascer legível para o grupo ou para todos, não adianta
    /// o app ser cuidadoso no resto.
    @Test("o arquivo nasce com permissão 0600")
    func permissao() throws {
        let f = arquivoTemporario()
        defer { try? FileManager.default.removeItem(at: f) }

        APIAccountStore.add(.init(providerId: "openrouter", label: "p", key: "sk-or-1"), to: f)
        let attrs = try FileManager.default.attributesOfItem(atPath: f.path)
        #expect(attrs[.posixPermissions] as? NSNumber == 0o600)
    }

    @Test("remover tira só a conta pedida")
    func remover() throws {
        let f = arquivoTemporario()
        defer { try? FileManager.default.removeItem(at: f) }

        let a = APIAccount(providerId: "openrouter", label: "pessoal", key: "sk-or-1")
        let b = APIAccount(providerId: "openrouter", label: "trabalho", key: "sk-or-2")
        APIAccountStore.add(a, to: f)
        APIAccountStore.add(b, to: f)
        APIAccountStore.remove(id: a.id, from: f)

        #expect(APIAccountStore.load(from: f).map(\.id) == [b.id])
    }

    @Test("a máscara não vaza o miolo da chave")
    func mascara() {
        let c = APIAccount(providerId: "openrouter", label: "p", key: "sk-or-v1-abcdef1234567890")
        #expect(c.maskedKey == "sk-or-…7890")
        #expect(!c.maskedKey.contains("abcdef"))
    }

    @Test("arquivo ausente devolve vazio em vez de quebrar")
    func ausente() {
        #expect(APIAccountStore.load(from: arquivoTemporario()).isEmpty)
    }

    @Test("lê o saldo da DeepSeek")
    func deepseek() {
        let json: [String: Any] = ["balance_infos": [["total_balance": "12.34"]]]
        #expect(APIQuotaProvider.parseDeepSeekBalance(json).remaining == 12.34)
    }

    @Test("lê o saldo da Moonshot")
    func moonshot() {
        let json: [String: Any] = ["data": ["available_balance": 7.5]]
        #expect(APIQuotaProvider.parseMoonshotBalance(json).remaining == 7.5)
    }

    /// O catálogo aqui espelha o `KEY_PROVIDERS` do Hyperion — se um sair de lá, some daqui.
    @Test("o catálogo cobre os provedores do Hyperion")
    func catalogo() {
        #expect(Set(APIProviderCatalog.all.map(\.id))
            == ["openrouter", "deepseek", "moonshot", "fireworks", "zai"])
    }
}
