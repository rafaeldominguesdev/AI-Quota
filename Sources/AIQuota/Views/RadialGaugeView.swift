import SwiftUI

/// O medidor radial do bloco principal: trilho de fundo hairline, arco preenchido na cor do
/// estado, percentual grande em mono bold no centro e o rótulo do estado em caixa alta embaixo.
struct RadialGaugeView: View {
    /// 0...100. `nil` quando o provedor não tem percentual algum — aí o anel fica só no trilho.
    let percent: Double?
    let level: UsageLevel?
    /// `true` quando o número veio do próprio provedor, e não da nossa estimativa de custo.
    let isOfficial: Bool
    var diameter: CGFloat = Theme.Metric.heroGauge

    private var fraction: CGFloat {
        CGFloat(min(max(percent ?? 0, 0), 100) / 100)
    }

    private var color: Color { level?.color ?? Theme.inkFaint }
    private var lineWidth: CGFloat { diameter * 0.065 }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Theme.hairline, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(lineWidth / 2)
                .shadow(color: color.opacity(0.22), radius: 5)
                .animation(Theme.Motion.gauge, value: fraction)

            VStack(spacing: 3) {
                if let percent {
                    CountingNumberText(value: percent) { QuotaFormatting.percent($0) }
                        .font(Theme.mono(Theme.Size.gauge, .bold))
                        .foregroundStyle(color)
                        .animation(Theme.Motion.count, value: percent)
                } else {
                    Text("—")
                        .font(Theme.mono(Theme.Size.gauge, .bold))
                        .foregroundStyle(Theme.inkFaint)
                }

                Text(level?.label ?? "Sem dado")
                    .font(Theme.mono(Theme.Size.micro, .bold))
                    .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.micro))
                    .textCase(.uppercase)
                    .foregroundStyle(level == nil ? Theme.inkFaint : color.opacity(0.85))

                if percent != nil {
                    Text(isOfficial ? "Oficial" : "Estimado")
                        .font(Theme.mono(Theme.Size.micro, .medium))
                        .tracking(Theme.tracking(Theme.Em.subtle, at: Theme.Size.micro))
                        .textCase(.uppercase)
                        .foregroundStyle(isOfficial ? Theme.secondary : Theme.inkFaint)
                }
            }
        }
        .frame(width: diameter, height: diameter)
    }
}
