import SwiftUI
import AIQuotaCore

/// Uma linha do painel, e o painel é só uma pilha delas:
///
///     [logo]  NOME-DA-IA        [barrinha]  42%
///
/// Provedor sem percentual troca a barra pelo dado que existir em texto apagado e o número por
/// um traço.
struct ProviderRowView: View {
    let presentation: ProviderPresentation

    private var isDim: Bool { presentation.percent == nil }

    var body: some View {
        HStack(spacing: 8) {
            ProviderGlyphView(
                glyph: ProviderGlyph.forProvider(id: presentation.id),
                color: isDim ? Theme.inkDim : presentation.accent,
                side: Theme.Metric.glyphSide
            )

            Text(presentation.displayName)
                .font(Theme.mono(Theme.Size.small, .medium))
                .tracking(Theme.tracking(Theme.Em.subtle, at: Theme.Size.small))
                .textCase(.uppercase)
                .foregroundStyle(isDim ? Theme.inkFaint : Theme.ink)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 6)

            if let percent = presentation.percent {
                UsageBar(fraction: percent / 100, color: presentation.accent)
                    .animation(Theme.Motion.bar, value: percent)

                Text(QuotaFormatting.percent(percent))
                    .font(Theme.mono(Theme.Size.small, .medium))
                    .foregroundStyle(presentation.accent)
                    .frame(width: Theme.Metric.percentColumnWidth, alignment: .trailing)
            } else {
                Text(presentation.fallbackValue ?? "")
                    .font(Theme.mono(Theme.Size.micro))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
                    .frame(width: Theme.Metric.usageBarWidth, alignment: .trailing)

                Text("—")
                    .font(Theme.mono(Theme.Size.small))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(width: Theme.Metric.percentColumnWidth, alignment: .trailing)
            }

            // Marca mínima de que o percentual é oficial, e não estimativa nossa. A coluna é
            // reservada mesmo quando vazia, senão as linhas desalinham.
            ZStack {
                if presentation.isPercentOfficial {
                    Circle()
                        .fill(Theme.secondary)
                        .frame(width: Theme.Metric.officialDotSide, height: Theme.Metric.officialDotSide)
                }
            }
            .frame(width: Theme.Metric.officialDotColumnWidth)
        }
        .frame(height: Theme.Metric.rowHeight)
        .help(tooltip)
    }

    /// Quem quiser saber o que a linha esconde passa o mouse — é o único lugar onde a explicação
    /// aparece, para o painel não virar texto.
    private var tooltip: String {
        if let official = presentation.snapshot.officialLimit {
            var text = "Limite oficial do provedor"
            if let resetsAt = official.resetsAt {
                text += " — reseta às \(QuotaFormatting.time(resetsAt))"
            }
            return text
        }
        if let note = presentation.note { return note }
        if let resetsAt = presentation.resetsAt {
            return "Uso estimado na janela de 5h — reseta às \(QuotaFormatting.time(resetsAt))"
        }
        return presentation.displayName
    }
}
