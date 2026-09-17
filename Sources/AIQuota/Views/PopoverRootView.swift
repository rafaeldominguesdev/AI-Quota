import SwiftUI
import AppKit

/// Raiz do painel: cabeçalho fixo, corpo trocável (painel ⇄ provedores) e rodapé, com hairlines
/// separando os três. Largura fixa de 380pt e altura dinâmica até um teto, quando o corpo passa
/// a rolar.
struct PopoverRootView: View {
    @ObservedObject var store: QuotaStore

    private enum Screen {
        case dashboard
        case providers
    }

    @ViewState private var screen: Screen = .dashboard
    @ViewState private var expandedProviderId: String?
    @ViewState private var bodyHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar()
            Hairline()
            bodyArea
            Hairline()
            footer
        }
        .frame(width: Theme.Metric.panelWidth)
        .background(Theme.bg)
        .overlay(ScanlineOverlay())
        .environment(\.colorScheme, .dark)
        .onAppear { store.refreshNow() }
    }

    // MARK: - Corpo

    private var bodyArea: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                switch screen {
                case .dashboard:
                    DashboardView(store: store, expandedProviderId: $expandedProviderId)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .providers:
                    ProvidersScreenView(store: store, onBack: { go(to: .dashboard) })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .frame(width: Theme.Metric.panelWidth, alignment: .topLeading)
            .background(HeightReader())
        }
        .frame(height: min(max(bodyHeight, 80), Theme.Metric.bodyMaxHeight))
        .onPreferenceChange(BodyHeightKey.self) { height in
            // A altura do painel acompanha o conteúdo (expandir um provedor cresce o popover)
            // até o teto, e só então o corpo passa a rolar.
            bodyHeight = height
        }
        .animation(Theme.Motion.expand, value: bodyHeight)
        .clipped()
    }

    // MARK: - Rodapé

    private var footer: some View {
        HStack(spacing: 7) {
            // Indicador de leitura: o ponto pulsa em vermelho enquanto a varredura roda e o
            // relógio marca a última atualização concluída.
            if store.isRefreshing {
                PulsingDot(color: Theme.primary, side: 4)
            } else {
                StatusSquare(color: Theme.tok.opacity(0.6), side: 4)
            }

            if let lastUpdated = store.lastUpdated {
                Text(QuotaFormatting.clock(lastUpdated))
                    .font(Theme.mono(Theme.Size.micro, .medium))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
                    .fixedSize()
            }

            Spacer(minLength: 0)

            TerminalButton(title: "Atualizar", color: Theme.tok) {
                store.refreshNow()
            }

            TerminalButton(
                title: screen == .providers ? "Painel" : "Provedores",
                color: Theme.secondary
            ) {
                go(to: screen == .providers ? .dashboard : .providers)
            }

            TerminalButton(title: "Sair", color: Theme.primary) {
                NSApp.terminate(nil)
            }
        }
        .padding(.horizontal, Theme.Metric.padding)
        .padding(.vertical, 9)
    }

    private func go(to destination: Screen) {
        withAnimation(Theme.Motion.screen) { screen = destination }
    }
}

// MARK: - Cabeçalho

/// "AI QUOTA" em caixa alta com tracking largo no vermelho da marca, e à direita o relógio mono
/// com um ponto pulsante verde indicando que a leitura está ao vivo.
private struct HeaderBar: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("AI Quota")
                .font(Theme.mono(12, .bold))
                .tracking(Theme.tracking(Theme.Em.label, at: 12))
                .textCase(.uppercase)
                .foregroundStyle(Theme.primary)
                .shadow(color: Theme.primary.opacity(0.18), radius: 4)

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: Theme.Metric.hairline)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(QuotaFormatting.clock(context.date))
                    .font(Theme.mono(Theme.Size.small, .medium))
                    .tracking(Theme.tracking(Theme.Em.subtle, at: Theme.Size.small))
                    .foregroundStyle(Theme.inkDim)
            }

            PulsingDot()
        }
        .padding(.horizontal, Theme.Metric.padding)
        .padding(.vertical, 10)
    }
}

// MARK: - Medição de altura

private struct BodyHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Publica a altura natural do conteúdo para o painel dimensionar o corpo rolável.
private struct HeightReader: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear.preference(key: BodyHeightKey.self, value: geometry.size.height)
        }
    }
}
