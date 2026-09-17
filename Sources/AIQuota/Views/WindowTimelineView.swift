import SwiftUI
import AIQuotaCore

/// A timeline da janela de 5h: uma barra segmentada em 5 blocos de 1h que mostra, sobrepostos,
/// quanto da janela já PASSOU (cinza quente, o "passado") e quanto dela já foi CONSUMIDO
/// (faixa na cor do estado, embaixo). Um marcador vertical de 1px indica o instante atual.
///
/// Comparar as duas camadas é a leitura que importa: faixa mais curta que o cinza significa
/// que o ritmo de consumo está abaixo do ritmo do tempo.
struct WindowTimelineView: View {
    let windowStart: Date
    let windowEnd: Date
    let now: Date
    /// 0...1 de consumo da janela, ou `nil` quando o provedor não tem percentual.
    let usageFraction: Double?
    let color: Color

    private let segmentCount = UsageWindowBuilder.hourlySlotCount
    private let gap: CGFloat = 2
    private let barHeight: CGFloat = 20
    private let usageStripHeight: CGFloat = 5

    private var elapsedFraction: CGFloat {
        let total = windowEnd.timeIntervalSince(windowStart)
        guard total > 0 else { return 0 }
        return CGFloat(min(max(now.timeIntervalSince(windowStart) / total, 0), 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel(
                text: "Janela de 5h",
                trailing: "\(QuotaFormatting.time(windowStart)) → \(QuotaFormatting.time(windowEnd))"
            )

            GeometryReader { geometry in
                let width = geometry.size.width
                let segmentWidth = max(1, (width - gap * CGFloat(segmentCount - 1)) / CGFloat(segmentCount))

                ZStack(alignment: .topLeading) {
                    ForEach(0..<segmentCount, id: \.self) { index in
                        segment(index: index, width: segmentWidth)
                            .offset(x: CGFloat(index) * (segmentWidth + gap))
                    }

                    // Marcador do instante atual — a linha de 1px que "anda" pela janela.
                    Rectangle()
                        .fill(Theme.ink.opacity(0.7))
                        .frame(width: Theme.Metric.hairline, height: barHeight)
                        .offset(x: min(width - 1, width * elapsedFraction))
                }
            }
            .frame(height: barHeight)

            hourRuler

            legend
        }
    }

    // MARK: - Partes

    private func segment(index: Int, width: CGFloat) -> some View {
        // Fração de tempo já decorrida DENTRO deste bloco de 1h.
        let timeFraction = min(max(elapsedFraction * CGFloat(segmentCount) - CGFloat(index), 0), 1)
        // O consumo é distribuído linearmente pela barra, de modo que o comprimento total da
        // faixa colorida corresponda exatamente ao percentual de uso.
        let usage = usageFraction.map {
            min(max(CGFloat($0) * CGFloat(segmentCount) - CGFloat(index), 0), 1)
        } ?? 0

        return ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Theme.surface)

            Rectangle()
                .fill(Theme.rain.opacity(0.55))
                .frame(width: width * timeFraction)

            if usage > 0 {
                Rectangle()
                    .fill(color)
                    .frame(width: width * usage, height: usageStripHeight)
            }
        }
        .frame(width: width, height: barHeight)
        .overlay(
            Rectangle().strokeBorder(Theme.hairline, lineWidth: Theme.Metric.hairline)
        )
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private var hourRuler: some View {
        HStack(spacing: gap) {
            ForEach(0..<segmentCount, id: \.self) { index in
                let slotStart = windowStart.addingTimeInterval(Double(index) * 3600)
                Text(QuotaFormatting.hourLabel(slotStart) + "h")
                    .font(Theme.mono(Theme.Size.micro, .medium))
                    .foregroundStyle(elapsedFraction * CGFloat(segmentCount) > CGFloat(index) ? Theme.inkMuted : Theme.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 10) {
            legendItem(swatch: Theme.rain, label: "Tempo", value: QuotaFormatting.percent(Double(elapsedFraction) * 100))
            if let usageFraction {
                legendItem(swatch: color, label: "Uso", value: QuotaFormatting.percent(usageFraction * 100))
            }
            Spacer(minLength: 0)
        }
    }

    private func legendItem(swatch: Color, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            StatusSquare(color: swatch, side: 5)
            Text(label)
                .font(Theme.mono(Theme.Size.micro, .bold))
                .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.micro))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkMuted)
            Text(value)
                .font(Theme.mono(Theme.Size.micro, .medium))
                .foregroundStyle(Theme.inkDim)
        }
    }
}
