import AppKit

/// Desenha o medidor do NSStatusItem: um anel de progresso de ~14pt, com trilho apagado e
/// preenchimento na cor do estado. Substitui o SF Symbol genérico — o ícone é do app, não do
/// sistema.
///
/// `isTemplate` fica `false` de propósito: a imagem tem cor própria (verde/âmbar/vermelho) e
/// não deve ser recolorida pelo tema da barra de menu.
enum MenuBarGauge {
    /// - Parameters:
    ///   - fraction: 0...1 de preenchimento, ou `nil` para desenhar só o trilho (sem dado).
    ///   - color: cor do arco preenchido.
    ///   - diameter: diâmetro do anel em pontos.
    static func image(fraction: Double?, color: NSColor, diameter: CGFloat = 14) -> NSImage {
        let lineWidth: CGFloat = 2
        let size = NSSize(width: diameter, height: diameter)
        let image = NSImage(size: size)

        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = false
        }

        NSGraphicsContext.current?.imageInterpolation = .high

        let center = NSPoint(x: diameter / 2, y: diameter / 2)
        let radius = (diameter - lineWidth) / 2

        // Trilho: o anel completo, apagado, para o arco ter contra o que ser lido.
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = lineWidth
        Theme.NS.track.setStroke()
        track.stroke()

        guard let fraction else {
            // Sem dado: um ponto central apagado em vez de um anel vazio ambíguo.
            let dotSide = lineWidth * 1.6
            let dot = NSBezierPath(ovalIn: NSRect(
                x: center.x - dotSide / 2, y: center.y - dotSide / 2,
                width: dotSide, height: dotSide
            ))
            Theme.NS.inkFaint.setFill()
            dot.fill()
            return image
        }

        let clamped = min(max(fraction, 0), 1)
        guard clamped > 0 else { return image }

        // Começa no topo (90°) e avança no sentido do relógio, como um medidor de verdade.
        let startAngle: CGFloat = 90
        let endAngle = startAngle - 360 * CGFloat(clamped)
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        color.setStroke()
        arc.stroke()

        return image
    }
}
