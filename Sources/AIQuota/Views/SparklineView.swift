import SwiftUI

/// Sparkline de barras: distribuição do uso hora a hora dentro da janela atual, com a hora de
/// pico destacada. Mostra *quando* a cota foi queimada, coisa que o percentual sozinho esconde.
struct SparklineView: View {
    /// Um valor por hora da janela (tokens, ou contagem de eventos em provedores sem token).
    let buckets: [Int]
    let color: Color
    /// Como escrever o valor de pico ao lado do rótulo.
    let formatPeak: (Int) -> String

    private let barHeight: CGFloat = 26

    private var peak: Int { buckets.max() ?? 0 }
    private var peakIndex: Int? {
        guard peak > 0 else { return nil }
        return buckets.firstIndex(of: peak)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel(
                text: "Uso por hora",
                trailing: peak > 0 ? "Pico \(formatPeak(peak))" : nil
            )

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(buckets.enumerated()), id: \.offset) { index, value in
                    let fraction = peak > 0 ? CGFloat(value) / CGFloat(peak) : 0
                    ZStack(alignment: .bottom) {
                        Rectangle()
                            .fill(Theme.surface)
                            .frame(height: barHeight)
                        Rectangle()
                            .fill(index == peakIndex ? color : Theme.tok.opacity(0.55))
                            // 1pt mínimo para uma hora com uso baixo não desaparecer de vez;
                            // zero de verdade continua sem barra nenhuma.
                            .frame(height: value > 0 ? max(1, barHeight * fraction) : 0)
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }
            .frame(height: barHeight)
            .animation(Theme.Motion.gauge, value: buckets)
        }
    }
}
