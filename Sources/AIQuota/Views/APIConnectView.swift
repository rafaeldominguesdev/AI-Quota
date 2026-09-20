import SwiftUI
import AppKit
import AIQuotaCore

/// A parte da aba CONECTAR que realmente CONECTA.
///
/// O resto da aba detecta CLI no disco — e detecção falha: a pasta mudou, a pessoa usa outro
/// `HOME`, a CLI ainda não escreveu log. Provedor por chave não tem esse problema nem essa
/// saída: ou existe uma chave cadastrada, ou não existe. Aqui a pessoa cola a chave, o app
/// bate na API do provedor ANTES de salvar, e só guarda o que respondeu.
struct APIConnectView: View {
    @ObservedObject var store: QuotaStore

    @ViewState private var accounts: [APIAccount] = []
    @ViewState private var abertoId: String?
    @ViewState private var rotulo: String = ""
    @ViewState private var chave: String = ""
    @ViewState private var testando = false
    @ViewState private var erro: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Conectar por chave de API")

            VStack(spacing: Theme.Metric.Settings.cardGap) {
                ForEach(APIProviderCatalog.all) { def in
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 10) {
                            cabecalho(def)
                            contasDe(def)
                            if abertoId == def.id { formulario(def) }
                        }
                    }
                }
            }
        }
        .onAppear { accounts = APIAccountStore.load() }
    }

    // MARK: - Linhas

    private func cabecalho(_ def: APIProviderDef) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(def.displayName)
                    .font(Theme.mono(Theme.Size.small, .medium))
                    .foregroundStyle(Theme.ink)
                Text(legenda(def))
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 12)
            GhostButton(title: "Pegar chave") {
                if let u = URL(string: def.keysURL) { NSWorkspace.shared.open(u) }
            }
            GhostButton(title: abertoId == def.id ? "Cancelar" : "Conectar") {
                erro = nil
                if abertoId == def.id {
                    abertoId = nil
                } else {
                    abertoId = def.id
                    rotulo = sugestaoDeRotulo(def)
                    chave = ""
                }
            }
        }
    }

    /// O que este provedor consegue reportar — dito ANTES de a pessoa conectar, não depois.
    /// Prometer barra de consumo pra quem não publica endpoint de cota seria decepção agendada.
    private func legenda(_ def: APIProviderDef) -> String {
        switch def.usage {
        case .openRouter: return "reporta crédito, gasto e free tier"
        case .deepSeekBalance, .moonshotBalance: return "reporta saldo restante"
        case .validateOnly: return "sem endpoint de cota — só valida a chave"
        }
    }

    private func contasDe(_ def: APIProviderDef) -> some View {
        let minhas = accounts.filter { $0.providerId == def.id }
        return VStack(spacing: 6) {
            ForEach(minhas) { conta in
                HStack(spacing: 10) {
                    Circle().fill(Theme.calm).frame(width: 5, height: 5)
                    Text(conta.label)
                        .font(Theme.mono(Theme.Size.micro, .medium))
                        .foregroundStyle(Theme.ink)
                    Text(conta.maskedKey)
                        .font(Theme.mono(Theme.Size.micro))
                        .foregroundStyle(Theme.inkFaint)
                    Spacer(minLength: 8)
                    GhostButton(title: "Remover") {
                        APIAccountStore.remove(id: conta.id)
                        accounts = APIAccountStore.load()
                        store.refreshNow()
                    }
                }
            }
        }
    }

    private func formulario(_ def: APIProviderDef) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Hairline()
            HStack(spacing: 8) {
                TextField("rótulo (pessoal, trabalho…)", text: $rotulo)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.ink)
                    .padding(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .strokeBorder(Theme.lineStrong, lineWidth: Theme.Metric.border)
                    )
                    .frame(width: 150)

                // SecureField e não TextField: a janela de Ajustes é o que a pessoa deixa
                // aberta numa chamada compartilhando a tela.
                SecureField("cole a chave aqui", text: $chave)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.ink)
                    .padding(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .strokeBorder(Theme.lineStrong, lineWidth: Theme.Metric.border)
                    )
            }

            HStack(spacing: 10) {
                PrimaryButton(title: testando ? "Testando…" : "Salvar") { salvar(def) }
                if let erro {
                    Text(erro)
                        .font(Theme.mono(Theme.Size.micro))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    // MARK: - Ações

    /// "pessoal" na primeira conta; depois "conta 2", "conta 3"… O rótulo entra no nome do
    /// provedor quando há mais de uma, então precisa nascer diferente.
    private func sugestaoDeRotulo(_ def: APIProviderDef) -> String {
        let n = accounts.filter { $0.providerId == def.id }.count
        return n == 0 ? "pessoal" : "conta \(n + 1)"
    }

    private func salvar(_ def: APIProviderDef) {
        let k = chave.trimmingCharacters(in: .whitespacesAndNewlines)
        let r = rotulo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { erro = "cole a chave"; return }
        guard !r.isEmpty else { erro = "dê um rótulo"; return }
        // Checagem de prefixo antes da rede: erro de colar chave do provedor errado é o mais
        // comum, e não precisa de ida ao servidor pra ser pego.
        if let p = def.keyPrefix, !k.hasPrefix(p) {
            erro = "chave do \(def.displayName) começa com \(p)"
            return
        }

        testando = true
        erro = nil
        let conta = APIAccount(providerId: def.id, label: r, key: k)

        Task.detached(priority: .userInitiated) {
            let provider = APIQuotaProvider(def: def, account: conta)
            var falha: String?
            do {
                _ = try provider.snapshot(config: .defaultConfig)
            } catch {
                falha = error.localizedDescription
            }
            let resultado = falha
            await MainActor.run {
                testando = false
                if let resultado {
                    // Não salva o que não respondeu: conta cadastrada que não autentica vira
                    // uma linha permanentemente vermelha no painel.
                    erro = resultado
                    return
                }
                APIAccountStore.add(conta)
                accounts = APIAccountStore.load()
                abertoId = nil
                chave = ""
                store.refreshNow()
            }
        }
    }
}
