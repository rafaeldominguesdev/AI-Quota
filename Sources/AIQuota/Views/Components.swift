import SwiftUI

/// A hairline de 1px: é o único separador do painel.
struct Hairline: View {
    var color: Color = Theme.line

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: Theme.Metric.border)
    }
}

/// Ação em texto puro, em caixa alta pequena com tracking — sem caixa, sem borda, sem botão
/// desenhado. Só a cor muda no hover.
struct TextAction: View {
    let title: String
    var action: () -> Void

    @ViewState private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.mono(Theme.Size.micro, .bold))
                .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.micro))
                .textCase(.uppercase)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isHovering ? Theme.ink : Theme.inkMuted)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Theme.Motion.fast) { isHovering = hovering }
        }
    }
}

/// O separador entre as ações do rodapé.
struct ActionSeparator: View {
    var body: some View {
        Text("·")
            .font(Theme.mono(Theme.Size.micro))
            .foregroundStyle(Theme.lineStrong)
    }
}

/// O selo quadrado com a inicial do plano da conta ("P" de Plus/Pro, "M" de Max), ao lado do
/// e-mail mascarado — é o `[M]`/`[P]` do print de referência do painel.
struct PlanBadgeSquare: View {
    let letter: String
    var side: CGFloat = 18

    var body: some View {
        Text(letter)
            .font(Theme.mono(Theme.Size.small, .bold))
            .foregroundStyle(Theme.ink)
            .frame(width: side, height: side)
            .overlay(
                Rectangle()
                    .strokeBorder(Theme.line, lineWidth: Theme.Metric.border)
            )
    }
}

/// A barrinha de uso: trilho hairline e preenchimento na cor do estado.
struct UsageBar: View {
    let fraction: Double
    let color: Color
    var width: CGFloat = Theme.Metric.usageBarWidth
    var height: CGFloat = Theme.Metric.usageBarHeight

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Theme.track)
            Capsule()
                .fill(color)
                // Abaixo de uma altura de largura não há proporção para mostrar: o mínimo
                // visível é a própria bolinha, e zero de verdade não desenha nada.
                .frame(width: fraction > 0 ? max(height, width * CGFloat(min(fraction, 1))) : 0)
        }
        .frame(width: width, height: height)
    }
}
