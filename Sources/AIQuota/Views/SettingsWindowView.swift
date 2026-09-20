import SwiftUI
import AppKit
import AIQuotaCore

/// A janela de Ajustes — uma janela de verdade, separada do popover da barra de menu.
///
/// Toda a geometria aqui foi MEDIDA do print de referência do usuário (680×656), não estimada:
/// cards de raio 8 com 16 de intervalo, hairline `#1F2937` desenhando a caixa, barra de 4px de
/// altura em trilha da mesma cor, linhas de janela a cada 16px, e as colunas de rótulo/barra/
/// percentual/reset nas larguras do print. Ver `Theme.Metric.Settings`.
struct SettingsWindowView: View {
    @ObservedObject var store: QuotaStore

    enum Tab: String, CaseIterable, Identifiable {
        case status = "STATUS"
        case connect = "CONECTAR"
        case preferences = "AJUSTES"
        var id: String { rawValue }
    }

    @ViewState private var tab: Tab = .status
    @ViewState private var isLoginItemEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tabs
            Hairline()

            ScrollView {
                SettingsTabContent(
                    store: store,
                    tab: tab,
                    isLoginItemEnabled: isLoginItemEnabled,
                    toggleLoginItem: toggleLoginItem
                )
            }

            Hairline()
            footer
        }
        .frame(
            width: Theme.Metric.Settings.width,
            height: Theme.Metric.Settings.height,
            alignment: .topLeading
        )
        .background(Theme.bg)
        .environment(\.colorScheme, .dark)
        .onAppear {
            store.refreshNow()
            isLoginItemEnabled = LoginItemManager.isEnabled
        }
    }

    // MARK: - Cabeçalho

    /// A assinatura: nome em branco, segunda palavra no vermelho REDLINE. É o único lugar da
    /// janela onde o acento aparece fora do botão primário e do semáforo.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(spacing: 9) {
                AIQuotaMark(side: 22)
                    // O conta-giros tem o vão embaixo, então o peso visual dele sobe: sem este
                    // empurrão ele flutua acima da linha de base do texto.
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }

                HStack(spacing: 7) {
                    Text("AI")
                        .foregroundStyle(Theme.ink)
                    Text("QUOTA")
                        .foregroundStyle(Theme.accent)
                }
                .font(Theme.mono(Theme.Size.body, .bold))
                .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.body))
            }

            Spacer(minLength: 12)

            if let email = store.primary?.maskedAccountEmail {
                Text(email)
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkDim)
            }
            if let letter = store.primary?.planBadgeLetter {
                PlanBadgeSquare(letter: letter, side: 15)
            }
        }
        .padding(.horizontal, Theme.Metric.Settings.gutter + 4)
        .padding(.top, 22)
        .padding(.bottom, 18)
    }

    // MARK: - Abas

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { item in
                TabButton(title: item.rawValue, isActive: tab == item) {
                    withAnimation(Theme.Motion.screen) { tab = item }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Rodapé

    private var footer: some View {
        HStack(spacing: 10) {
            if let lastUpdated = store.lastUpdated {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text("Última leitura: " + QuotaFormatting.elapsed(since: lastUpdated, now: context.date))
                        .font(Theme.mono(Theme.Size.micro))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            Spacer(minLength: 0)
            PrimaryButton(title: "Pronto") { SettingsWindowController.shared.close() }
        }
        .padding(.horizontal, Theme.Metric.Settings.gutter + 4)
        .padding(.vertical, 14)
    }

    private func toggleLoginItem() {
        let target = !isLoginItemEnabled
        if LoginItemManager.setEnabled(target) {
            isLoginItemEnabled = target
        }
    }
}

/// O miolo de cada aba, separado da janela de propósito: o `ScrollView` fica só lá fora, e assim
/// este conteúdo pode ser renderizado direto (o `ImageRenderer` devolve branco para o que está
/// dentro de um ScrollView, o que inutilizava a conferência visual).
struct SettingsTabContent: View {
    @ObservedObject var store: QuotaStore
    let tab: SettingsWindowView.Tab
    let isLoginItemEnabled: Bool
    let toggleLoginItem: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch tab {
            case .status: statusTab
            case .connect: connectTab
            case .preferences: preferencesTab
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Metric.Settings.gutter)
        .padding(.vertical, Theme.Metric.Settings.gutter)
    }

    // MARK: - Aba STATUS

    var statusTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Contas monitoradas") {
                GhostButton(title: "Atualizar") { store.refreshNow() }
            }

            let connected = store.providerRows.filter(\.isConnected)
            if connected.isEmpty {
                EmptyLine(text: store.overview == nil ? "Lendo os logs locais…" : "Nenhuma conta conectada ainda — veja a aba CONECTAR.")
            } else {
                VStack(spacing: Theme.Metric.Settings.cardGap) {
                    ForEach(ProviderGrouping.group(connected)) { group in
                        ForEach(group.accounts, id: \.id) { account in
                            AccountCard(presentation: account, family: group.displayName)
                        }
                    }
                }
            }

            if !store.configWarnings.isEmpty {
                SectionHeader(title: "Avisos de configuração")
                    .padding(.top, 20)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(store.configWarnings, id: \.self) { warning in
                        Text(warning)
                            .font(Theme.mono(Theme.Size.micro))
                            .foregroundStyle(Theme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Aba PROVIDERS

    /// As IAs que o app conhece mas que ainda NÃO estão conectadas (não logada, ou nem instalada).
    /// É aqui que o usuário vê o que falta para elas entrarem no painel — com o caminho no disco.
    /// As já conectadas ficam só na aba STATUS, para não repetir.
    var connectTab: some View {
        let presentations = Dictionary(uniqueKeysWithValues: store.providerRows.map { ($0.id, $0) })
        let pending = store.sources.filter { !(presentations[$0.id]?.isConnected ?? false) }

        return VStack(alignment: .leading, spacing: 0) {
            // Primeiro o que a pessoa CONECTA (chave de API), depois o que o app DETECTA
            // (CLI no disco). A detecção falha por motivos que não estão na mão de ninguém —
            // pasta movida, HOME diferente, log ainda não escrito —, então ela não pode ser
            // a única porta de entrada nem a primeira coisa da aba.
            APIConnectView(store: store)

            SectionHeader(title: "CLIs detectadas no disco") {
                GhostButton(title: "Detectar") { store.refreshNow() }
            }
            .padding(.top, 20)

            if store.sources.isEmpty {
                EmptyLine(text: "Varrendo o disco…")
            } else if pending.isEmpty {
                EmptyLine(text: "Tudo conectado. 🎉")
            } else {
                VStack(spacing: Theme.Metric.Settings.cardGap) {
                    ForEach(pending) { source in
                        ProviderCard(source: source, presentation: presentations[source.id])
                    }
                }
            }
        }
    }

    // MARK: - Aba AJUSTES

    var preferencesTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Comportamento")

            SettingsCard {
                CheckRow(
                    title: "Iniciar no login",
                    detail: "Registra o app como item de login de verdade (SMAppService)",
                    isOn: isLoginItemEnabled,
                    toggle: toggleLoginItem
                )
            }

            SectionHeader(title: "Arquivos")
                .padding(.top, 20)
            VStack(spacing: Theme.Metric.Settings.cardGap) {
                SettingsCard {
                    PathRow(
                        title: "Provedores customizados",
                        path: ProvidersConfigStore.defaultFile,
                        detail: "Acrescente qualquer CLI que escreva JSONL — vale sem recompilar"
                    )
                }
                SettingsCard {
                    PathRow(
                        title: "Jornal de leituras",
                        path: UsageObservationJournal.defaultFile,
                        detail: "A memória que detecta leitura defasada do endpoint na virada"
                    )
                }
            }
        }
    }

}
