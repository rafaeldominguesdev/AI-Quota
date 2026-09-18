import SwiftUI
import AppKit

/// Raiz do painel: cabeçalho de uma linha, a lista de IAs, um resumo discreto e o rodapé de
/// ações em texto. A altura é só o que o conteúdo pede.
struct PopoverRootView: View {
    @ObservedObject var store: QuotaStore

    private enum Screen {
        case panel
        case providers
    }

    @ViewState private var screen: Screen = .panel
    @ViewState private var isLoginItemEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            switch screen {
            case .panel:
                panel
            case .providers:
                ProvidersScreenView(store: store, onBack: { go(to: .panel) })
            }

            if screen == .panel { retrospecto }
            loginItemRow
            actions
        }
        .frame(width: Theme.Metric.panelWidth)
        .background(Theme.bg)
        .environment(\.colorScheme, .dark)
        .onAppear {
            store.refreshNow()
            isLoginItemEnabled = LoginItemManager.isEnabled
        }
    }

    // MARK: - Cabeçalho

    private var header: some View {
        HStack(spacing: 8) {
            Text("AI Quota")
                .font(Theme.mono(Theme.Size.label, .bold))
                .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.label))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkDim)
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

    /// Título + descrição de uma linha, do jeito de um subtítulo de item de menu do macOS. Abre
    /// um relatório HTML gerado na hora a partir dos logs locais (ver `Retrospecto.open()`) —
    /// nada de servidor, nada saindo desta máquina.
    private var retrospecto: some View {
        Button(action: Retrospecto.open) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Retrospecto")
                    .font(Theme.mono(Theme.Size.small, .bold))
                    .foregroundStyle(Theme.ink)

                Text("Abre no navegador o histórico de consumo das contas")
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Metric.padding)
        .padding(.top, 14)
    }

    /// Checkbox de verdade: só marca quando `SMAppService` confirma o registro, nunca de forma
    /// otimista (ver `LoginItemManager`).
    private var loginItemRow: some View {
        Button(action: toggleLoginItem) {
            HStack(spacing: 6) {
                Text(isLoginItemEnabled ? "✓" : "·")
                    .font(Theme.mono(Theme.Size.small, .bold))
                    .foregroundStyle(isLoginItemEnabled ? Theme.ink : Theme.inkFaint)
                    .frame(width: 10, alignment: .center)

                Text("Iniciar no login")
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkMuted)

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Metric.padding)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    /// Lista vertical, uma ação por linha — do jeito do print de referência, não mais um trio
    /// inline separado por "·".
    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextAction(title: screen == .providers ? "Painel" : "Ajustes") {
                go(to: screen == .providers ? .panel : .providers)
            }
            // Força uma checagem imediata — o auto-refresh de 30s já cobre o caso comum, isto é
            // só pra quem quer confirmar na hora (ex.: acabou de rodar o CLI de novo).
            TextAction(title: "Atualizar leituras") { store.refreshNow() }
            TextAction(title: "Encerrar") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, Theme.Metric.padding)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private func go(to destination: Screen) {
        withAnimation(Theme.Motion.screen) { screen = destination }
    }

    private func toggleLoginItem() {
        let target = !isLoginItemEnabled
        if LoginItemManager.setEnabled(target) {
            isLoginItemEnabled = target
        }
    }
}
