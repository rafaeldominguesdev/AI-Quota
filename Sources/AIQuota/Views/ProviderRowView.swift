import SwiftUI
import AIQuotaCore

/// Uma linha da lista de provedores: indicador de status, nome, badge de qualidade do dado e o
/// valor principal. Ganha barra fina quando há percentual, destaque azul quando o provedor
/// reporta limite OFICIAL, e expande para o detalhamento por modelo ao ser clicada.
struct ProviderRowView: View {
    let presentation: ProviderPresentation
    let isExpanded: Bool
    let onToggle: () -> Void

    @ViewState private var isHovering = false

    private var isDead: Bool { presentation.snapshot.kind == .unavailable }
    private var nameColor: Color {
        if isDead { return Theme.inkFaint }
        return presentation.isPrimary ? Theme.ink : Theme.inkDim
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button(action: onToggle) {
                headline
            }
            .buttonStyle(.plain)
            .disabled(!presentation.isExpandable)

            if let official = presentation.snapshot.officialLimit {
                officialLimitBlock(official)
            }

            if let percent = presentation.percent, !presentation.isPercentOfficial {
                MicroBar(fraction: percent / 100, color: presentation.accent)
                    .animation(Theme.Motion.gauge, value: percent)
            }

            if isDead, let note = presentation.note {
                Text(note)
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isExpanded {
                detail
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(isExpanded || isHovering ? Theme.surface : Theme.bgSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(
                    isExpanded || isHovering ? Theme.hairlineStrong : Theme.hairline,
                    lineWidth: Theme.Metric.hairline
                )
        )
        .overlay(alignment: .leading) {
            // Marca do provedor principal: a barra vermelha na borda, em vez de um badge de
            // texto que roubaria a largura do valor.
            if presentation.isPrimary {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.primary)
                    .frame(width: 2)
                    .padding(.vertical, 6)
            }
        }
        .onHover { hovering in
            withAnimation(Theme.Motion.fast) { isHovering = hovering }
        }
    }

    // MARK: - Cabeçalho da linha

    private var headline: some View {
        HStack(spacing: 7) {
            StatusSquare(color: presentation.accent)

            Text(presentation.displayName)
                .font(Theme.mono(Theme.Size.body, presentation.isPrimary ? .bold : .regular))
                .foregroundStyle(nameColor)
                .lineLimit(1)

            Badge(text: presentation.kindBadge, color: isDead ? Theme.inkFaint : Theme.inkMuted)

            Spacer(minLength: 6)

            if let value = presentation.primaryValue {
                Text(value)
                    .font(Theme.mono(Theme.Size.body, .medium))
                    .foregroundStyle(isDead ? Theme.inkFaint : Theme.tok)
            }

            if presentation.isExpandable {
                Text("▸")
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkFaint)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(Theme.Motion.fast, value: isExpanded)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Limite oficial

    /// O dado mais valioso do app: não é estimativa nossa, é o próprio provedor dizendo quanto
    /// da cota foi usada. Ganha bloco próprio, borda azul e o percentual em destaque.
    private func officialLimitBlock(_ official: OfficialLimitInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Badge(text: "Limite oficial", color: Theme.secondary, emphasized: true)

                CountingNumberText(value: official.usedPercent) { QuotaFormatting.percent($0) }
                    .font(Theme.mono(Theme.Size.value, .bold))
                    .foregroundStyle(Theme.secondary)
                    .animation(Theme.Motion.count, value: official.usedPercent)

                Spacer(minLength: 4)

                if let resetsAt = official.resetsAt {
                    Text("Reseta \(QuotaFormatting.time(resetsAt))")
                        .font(Theme.mono(Theme.Size.micro, .medium))
                        .tracking(Theme.tracking(Theme.Em.subtle, at: Theme.Size.micro))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.secondaryDim)
                }
            }

            MicroBar(fraction: official.usedPercent / 100, color: Theme.secondary, height: 4)
                .animation(Theme.Motion.gauge, value: official.usedPercent)

            Text(official.label)
                .font(Theme.mono(Theme.Size.micro))
                .foregroundStyle(Theme.inkMuted)
                .lineLimit(1)
        }
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .fill(Theme.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .strokeBorder(Theme.secondary.opacity(0.35), lineWidth: Theme.Metric.hairline)
        )
    }

    // MARK: - Detalhamento por modelo

    private var detail: some View {
        VStack(alignment: .leading, spacing: 6) {
            Hairline()

            HStack(spacing: 8) {
                Text("Por modelo")
                    .font(Theme.mono(Theme.Size.micro, .bold))
                    .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.micro))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkMuted)

                Spacer(minLength: 0)

                if let start = presentation.snapshot.windowStart, let end = presentation.snapshot.windowEnd {
                    Text("\(QuotaFormatting.time(start)) → \(QuotaFormatting.time(end))")
                        .font(Theme.mono(Theme.Size.micro))
                        .foregroundStyle(Theme.inkFaint)
                }
            }

            ForEach(presentation.snapshot.byModel, id: \.model) { entry in
                modelRow(entry)
            }

            if presentation.snapshot.kind != .unavailable {
                HStack(spacing: 6) {
                    Text("\(presentation.snapshot.eventCount) evento" + (presentation.snapshot.eventCount == 1 ? "" : "s"))
                        .font(Theme.mono(Theme.Size.micro))
                        .foregroundStyle(Theme.inkFaint)

                    if !presentation.snapshot.isActive {
                        Text("· janela encerrada")
                            .font(Theme.mono(Theme.Size.micro))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
            }

            if !isDead, let note = presentation.note {
                Text(note)
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func modelRow(_ entry: ProviderModelUsage) -> some View {
        let share = shareFraction(for: entry)

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(entry.model)
                    .font(Theme.mono(Theme.Size.small))
                    .foregroundStyle(Theme.inkDim)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 6)

                if presentation.snapshot.kind == .countOnly {
                    Text("\(entry.eventCount)×")
                        .font(Theme.mono(Theme.Size.small, .medium))
                        .foregroundStyle(Theme.tok)
                } else {
                    Text(QuotaFormatting.compactTokens(entry.totalTokens))
                        .font(Theme.mono(Theme.Size.small, .medium))
                        .foregroundStyle(Theme.tok)
                }

                if let cost = entry.cost, cost > 0 {
                    Text(QuotaFormatting.cost(cost))
                        .font(Theme.mono(Theme.Size.small, .medium))
                        .foregroundStyle(entry.isEstimatedPricing ? Theme.inkMuted : Theme.role)
                        .frame(width: 66, alignment: .trailing)
                }
            }

            if share > 0 {
                MicroBar(fraction: share, color: Theme.tok.opacity(0.7), height: 2)
            }
        }
    }

    /// Participação do modelo no total do provedor — em tokens, ou em eventos quando o provedor
    /// não reporta token nenhum.
    private func shareFraction(for entry: ProviderModelUsage) -> Double {
        if presentation.snapshot.kind == .countOnly {
            let total = presentation.snapshot.eventCount
            return total > 0 ? Double(entry.eventCount) / Double(total) : 0
        }
        let total = presentation.snapshot.totalTokens
        return total > 0 ? Double(entry.totalTokens) / Double(total) : 0
    }
}
