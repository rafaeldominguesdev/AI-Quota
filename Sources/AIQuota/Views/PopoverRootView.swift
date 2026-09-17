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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Hairline()

            switch screen {
            case .panel:
                panel
            case .providers:
                ProvidersScreenView(store: store, onBack: { go(to: .panel) })
            }

            Hairline()
            footer
        }
        .frame(width: Theme.Metric.panelWidth)
        .background(Theme.bg)
        .environment(\.colorScheme, .dark)
        .onAppear { store.refreshNow() }
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
        .padding(.vertical, 8)
    }

    // MARK: - Lista

    private var panel: some View {
        let rows = store.providerRows

        return VStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty {
                Text(store.overview == nil ? "Lendo os logs locais…" : "Nenhuma IA detectada.")
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, Theme.Metric.padding)
                    .padding(.vertical, 10)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Hairline()
                    }
                    ProviderRowView(presentation: row)
                        .padding(.horizontal, Theme.Metric.padding)
                }
            }

            if let summary = store.summaryLine {
                Text(summary)
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
                    .padding(.horizontal, Theme.Metric.padding)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Rodapé

    private var footer: some View {
        HStack(spacing: 6) {
            TextAction(title: "Atualizar") { store.refreshNow() }
            ActionSeparator()
            TextAction(title: screen == .providers ? "Painel" : "Provedores") {
                go(to: screen == .providers ? .panel : .providers)
            }
            ActionSeparator()
            TextAction(title: "Sair") { NSApp.terminate(nil) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Metric.padding)
        .padding(.vertical, 8)
    }

    private func go(to destination: Screen) {
        withAnimation(Theme.Motion.screen) { screen = destination }
    }
}
