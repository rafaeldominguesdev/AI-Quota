import SwiftUI

/// Barra de progresso grossa e arredondada, preenchida com a cor do estado atual.
struct ProgressBarView: View {
    let percent: Double
    let color: Color

    private var clampedFraction: CGFloat {
        CGFloat(min(max(percent, 0), 100) / 100)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.secondary.opacity(0.15))
                RoundedRectangle(cornerRadius: 7)
                    .fill(color)
                    .frame(width: max(14, geometry.size.width * clampedFraction))
            }
        }
        .frame(height: 14)
    }
}
