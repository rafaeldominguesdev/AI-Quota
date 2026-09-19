import SwiftUI
import AppKit

/// Raiz do painel: cabeçalho de uma linha, a lista de IAs, um resumo discreto e o rodapé de
/// ações em texto. A altura é só o que o conteúdo pede.
struct PopoverRootView: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            panel
            retrospecto
            actions
        }
        .frame(width: Theme.Metric.panelWidth)
        .background(Theme.bg)
        .background(providerShortcuts)
        .environment(\.colorScheme, .dark)
        .onAppear { store.refreshNow() }
    }

    /// Os atalhos de uma letra que abrem a página de cada IA no navegador.
    ///
    /// São botões de verdade, só invisíveis: `keyboardShortcut` é o mecanismo do SwiftUI, e um
    /// botão escondido atrás do painel é o jeito de registrar a tecla sem desenhar nada. Ficam
    /// fora de qualquer `if`, atrelados às IAs que o painel está mostrando, então a tecla vale
    /// exatamente para o que está na tela.
    ///
    /// Sem modificador de propósito: o painel não tem campo de texto, então uma letra solta não
    /// briga com nada. Depois de abrir o navegador o painel se fecha — deixá-lo aberto atrás do
    /// browser só atrapalharia.
    private var providerShortcuts: some View {
        ForEach(ProviderGrouping.group(store.connectedProviders)) { group in
            if let entry = ProviderWebConsole.entry(forProviderId: group.id) {
                Button("") {
                    ProviderWebConsole.open(providerId: group.id)
                    AppDelegate.shared?.closePopover()
                }
                .keyboardShortcut(KeyEquivalent(entry.key), modifiers: [])
                .opacity(0)
                .frame(width: 0, height: 0)
            }
        }
    }

    // MARK: - Cabeçalho

    private var header: some View {
        HStack(spacing: 8) {
            AIQuotaMark(side: 13)

            HStack(spacing: 5) {
                Text("AI")
                    .foregroundStyle(Theme.inkDim)
                Text("QUOTA")
                    .foregroundStyle(Theme.accent)
            }
            .font(Theme.mono(Theme.Size.label, .bold))
            .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.label))
            .lineLimit(1)
            .fixedSize()

            Spacer(minLength: 4)

            if let resetsAt = store.primary?.resetsAt {
                // Meio minuto de granularidade basta para um texto que só mostra horas e
                // minutos, e evita redesenhar o painel a cada segundo.
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(QuotaFormatting.remaining(until: resetsAt, now: context.date))
                        .font(Theme.mono(Theme.Size.micro, .medium))
                        .foregroundStyle(Theme.inkMuted)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .padding(.horizontal, Theme.Metric.padding)
        .padding(.vertical, 10)
    }

    // MARK: - Lista

    private var panel: some View {
        let groups = ProviderGrouping.group(store.connectedProviders)

        return VStack(alignment: .leading, spacing: 0) {
            if groups.isEmpty {
                Text(store.overview == nil ? "Lendo os logs locais…" : "Nenhuma IA detectada.")
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, Theme.Metric.padding)
                    .padding(.vertical, 10)
            } else {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        ProviderGroupHeaderView(group: group)
                        ForEach(group.accounts, id: \.id) { account in
                            ProviderRowView(presentation: account, showHeader: false)
                        }
                    }
                    .padding(.horizontal, Theme.Metric.padding)
                }
            }

            if let summary = store.summaryLine {
                Text(summary)
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
                    .padding(.horizontal, Theme.Metric.padding)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
            }
        }
    }

    // MARK: - Rodapé

    /// Abre um relatório HTML gerado na hora a partir dos logs locais (ver `Retrospecto.open()`)
    /// — nada de servidor, nada saindo desta máquina. Só o título: a descrição de uma linha que
    /// ficava embaixo saiu a pedido do usuário.
    private var retrospecto: some View {
        Button(action: Retrospecto.open) {
            Text("Retrospecto")
                .font(Theme.mono(Theme.Size.small, .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Metric.padding)
        .padding(.top, 14)
    }

    /// Lista vertical, uma ação por linha — do jeito do print de referência, não mais um trio
    /// inline separado por "·".
    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Abre a janela de Ajustes (680pt), fora do popover: configurar não cabe em 292pt
            // de largura numa superfície que fecha ao perder o foco.
            TextAction(title: "Ajustes") { SettingsWindowController.shared.show(store: store) }
            // Força uma checagem imediata — o auto-refresh de 30s já cobre o caso comum, isto é
            // só pra quem quer confirmar na hora (ex.: acabou de rodar o CLI de novo).
            TextAction(title: "Atualizar leituras") { store.refreshNow() }
            TextAction(title: "Encerrar") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, Theme.Metric.padding)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }
}
