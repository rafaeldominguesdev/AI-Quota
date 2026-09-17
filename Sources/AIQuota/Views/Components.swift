import SwiftUI

// MARK: - Rótulo de seção

/// O rótulo em MAIÚSCULAS, 10px, bold, com tracking largo. É o elemento que mais entrega a
/// identidade do DevTerm, então ele é um componente só para nunca sair torto.
struct SectionLabel: View {
    let text: String
    var color: Color = Theme.inkMuted
    var trailing: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(Theme.mono(Theme.Size.label, .bold))
                .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.label))
                .textCase(.uppercase)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: Theme.Metric.hairline)

            if let trailing {
                Text(trailing)
                    .font(Theme.mono(Theme.Size.label, .medium))
                    .tracking(Theme.tracking(Theme.Em.subtle, at: Theme.Size.label))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

// MARK: - Linha fina

/// A hairline de 1px. Borda fina em todo lugar é a assinatura do visual.
struct Hairline: View {
    var color: Color = Theme.hairline

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: Theme.Metric.hairline)
    }
}

// MARK: - Badge

/// Etiqueta minúscula com borda fina — usada para o tipo de dado do provedor e para destacar
/// o limite oficial.
struct Badge: View {
    let text: String
    var color: Color = Theme.inkMuted
    var emphasized = false

    var body: some View {
        Text(text)
            .font(Theme.mono(Theme.Size.micro, emphasized ? .bold : .medium))
            .tracking(Theme.tracking(Theme.Em.label, at: Theme.Size.micro))
            .textCase(.uppercase)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(emphasized ? color.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .strokeBorder(
                        emphasized ? color.opacity(0.5) : Theme.hairlineStrong,
                        lineWidth: Theme.Metric.hairline
                    )
            )
    }
}

// MARK: - Botão de terminal

/// Botão em mono maiúsculo pequeno com borda hairline; no hover a borda vira #242428.
struct TerminalButton: View {
    let title: String
    var color: Color = Theme.inkDim
    var action: () -> Void

    @ViewState private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.mono(Theme.Size.label, .bold))
                .tracking(Theme.tracking(Theme.Em.button, at: Theme.Size.label))
                .textCase(.uppercase)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(isHovering ? color : color.opacity(0.75))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .fill(isHovering ? color.opacity(0.06) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .strokeBorder(
                            isHovering ? Theme.hairlineStrong : Theme.hairline,
                            lineWidth: Theme.Metric.hairline
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Theme.Motion.fast) { isHovering = hovering }
        }
    }
}

// MARK: - Ponto pulsante

/// Indicador de "ao vivo": um ponto com opacidade pulsando, igual ao contador vivo do DevTerm.
struct PulsingDot: View {
    var color: Color = Theme.success
    var side: CGFloat = 5

    @ViewState private var isDim = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: side, height: side)
            .opacity(isDim ? 0.25 : 1)
            .onAppear {
                withAnimation(Theme.Motion.pulse) { isDim = true }
            }
    }
}

// MARK: - Indicador quadrado de status

struct StatusSquare: View {
    let color: Color
    var side: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: side, height: side)
    }
}

// MARK: - Barra fina de progresso

/// Barra de 3pt com trilho hairline — usada por linha de provedor.
struct MicroBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.hairline)
                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: height / 2))
    }
}

// MARK: - Número contando

/// Texto numérico que "conta" até o valor em vez de pular de uma vez. `animatableData` faz o
/// SwiftUI interpolar o número, e o `format` decide como cada quadro é escrito.
struct CountingNumberText: View, Animatable {
    var value: Double
    var format: (Double) -> String

    /// `nonisolated` porque é assim que o requisito existe de verdade: a máquina de animação do
    /// SwiftUI interpola este valor fora da main actor, enquanto `body` (e o resto de `View`)
    /// permanece isolado nela.
    nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(value))
    }
}

// MARK: - Scanline CRT

/// Varredura de CRT quase imperceptível (1px a cada 5px, opacidade 0.02) por cima do painel.
struct ScanlineOverlay: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(.white)
                )
                y += 5
            }
        }
        .opacity(0.02)
        .allowsHitTesting(false)
    }
}

// MARK: - Entrada escalonada

/// Faz a view entrar com fade + deslocamento curto, com atraso proporcional ao índice — é o que
/// dá a sensação de a lista de provedores "assentar" quando o popover abre.
struct StaggeredAppear: ViewModifier {
    let index: Int

    @ViewState private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 6)
            .onAppear {
                withAnimation(Theme.Motion.expand.delay(Double(index) * 0.045)) {
                    hasAppeared = true
                }
            }
    }
}

extension View {
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}
