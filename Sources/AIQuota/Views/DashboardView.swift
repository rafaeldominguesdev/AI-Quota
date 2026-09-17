import SwiftUI
import AIQuotaCore

/// O painel principal: bloco em destaque do provedor primário (medidor radial + números +
/// contagem regressiva), a timeline da janela de 5h, a distribuição por hora e a lista de
/// todos os provedores.
struct DashboardView: View {
    @ObservedObject var store: QuotaStore
    @Binding var expandedProviderId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let primary = store.primary {
                heroBlock(primary)

                if let start = primary.snapshot.windowStart, let end = primary.snapshot.windowEnd {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        WindowTimelineView(
                            windowStart: start,
                            windowEnd: end,
                            now: context.date,
                            usageFraction: primary.percent.map { $0 / 100 },
                            color: primary.accent
                        )
                    }
                }

                if !primary.hourlyUsage.isEmpty {
                    SparklineView(
                        buckets: primary.hourlyUsage,
                        color: primary.accent,
                        formatPeak: { peakFormatter(primary, $0) }
                    )
                }
            } else {
                emptyState
            }

            providersSection

            if !store.configWarnings.isEmpty {
                warningsSection
            }
        }
        .padding(.horizontal, Theme.Metric.padding)
        .padding(.vertical, 12)
    }

    // MARK: - Bloco principal

    private func heroBlock(_ primary: ProviderPresentation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(
                text: "Provedor principal",
                color: Theme.primaryDim,
                trailing: primary.displayName
            )

            HStack(alignment: .center, spacing: 14) {
                RadialGaugeView(
                    percent: primary.percent,
                    level: primary.level,
                    isOfficial: primary.isPercentOfficial
                )

                VStack(alignment: .leading, spacing: 9) {
                    if primary.snapshot.totalTokens > 0 {
                        stat(label: "Tokens na janela", color: Theme.tok) {
                            CountingNumberText(value: Double(primary.snapshot.totalTokens)) {
                                QuotaFormatting.tokens(Int($0))
                            }
                            .font(Theme.mono(Theme.Size.value, .bold))
                            .foregroundStyle(Theme.tok)
                            .animation(Theme.Motion.count, value: primary.snapshot.totalTokens)
                        }
                    }

                    if let cost = primary.cost {
                        stat(label: "Custo estimado", color: Theme.role) {
                            CountingNumberText(value: cost) { QuotaFormatting.cost($0) }
                                .font(Theme.mono(Theme.Size.value, .bold))
                                .foregroundStyle(Theme.role)
                                .animation(Theme.Motion.count, value: cost)
                        }
                    }

                    if let resetsAt = primary.resetsAt {
                        stat(label: "Reseta em", color: Theme.inkDim) {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text(QuotaFormatting.countdown(until: resetsAt, now: context.date))
                                    .font(Theme.mono(Theme.Size.countdown, .bold))
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                        Text("às \(QuotaFormatting.time(resetsAt))")
                            .font(Theme.mono(Theme.Size.micro))
                            .foregroundStyle(Theme.inkFaint)
                    } else if primary.snapshot.windowEnd != nil {
                        stat(label: "Janela", color: Theme.inkDim) {
                            Text("Encerrada")
                                .font(Theme.mono(Theme.Size.value, .bold))
                                .foregroundStyle(Theme.inkMuted)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func stat<Content: View>(
        label: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(Theme.mono(Theme.Size.micro, .bold))
                .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.micro))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkMuted)
            content()
        }
    }

    /// O pico do sparkline é escrito em tokens ou em interações, conforme o que o provedor sabe.
    private func peakFormatter(_ primary: ProviderPresentation, _ value: Int) -> String {
        switch primary.snapshot.kind {
        case .fullTokens, .tokensOnly:
            return QuotaFormatting.compactTokens(value) + " tok"
        case .countOnly:
            return "\(value)×"
        case .unavailable:
            return "—"
        }
    }

    // MARK: - Lista de provedores

    private var providersSection: some View {
        let rows = store.providerRows

        return VStack(alignment: .leading, spacing: 7) {
            SectionLabel(
                text: "Provedores",
                trailing: rows.isEmpty ? nil : "\(rows.count) detectados"
            )

            if rows.isEmpty {
                Text("Nenhum provedor detectado ainda.")
                    .font(Theme.mono(Theme.Size.small))
                    .foregroundStyle(Theme.inkFaint)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    ProviderRowView(
                        presentation: row,
                        isExpanded: expandedProviderId == row.id,
                        onToggle: {
                            withAnimation(Theme.Motion.expand) {
                                expandedProviderId = expandedProviderId == row.id ? nil : row.id
                            }
                        }
                    )
                    .staggeredAppear(index: index)
                }
            }
        }
    }

    // MARK: - Avisos de configuração

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel(text: "Avisos de providers.json", color: Theme.danger)

            ForEach(store.configWarnings, id: \.self) { warning in
                Text("· " + warning)
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Estado vazio

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: store.overview == nil ? "Varrendo logs" : "Sem dado")

            Text(store.overview == nil
                 ? "Lendo os logs locais dos provedores…"
                 : "Nenhum provedor com uso legível na janela atual.")
                .font(Theme.mono(Theme.Size.small))
                .foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
