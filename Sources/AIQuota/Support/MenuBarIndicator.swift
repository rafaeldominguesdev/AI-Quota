import AppKit

/// O indicador da barra de menu: a logo da IA principal e uma barrinha carregada ao lado. Nada
/// mais — o número fica no painel.
enum MenuBarIndicator {

    /// Ligue para voltar a escrever o percentual em texto ao lado da barrinha.
    static let showsPercentTextInMenuBar = false

    private static let glyphSide: CGFloat = 12
    private static let gap: CGFloat = 4
    private static let barWidth: CGFloat = 20
    private static let barHeight: CGFloat = 3.5

    static var imageSize: NSSize {
        NSSize(width: glyphSide + gap + barWidth, height: glyphSide)
    }

    /// - Parameters:
    ///   - glyph: a marca do provedor principal.
    ///   - fraction: 0...1 de preenchimento da barra, ou `nil` quando não há percentual — aí só
    ///     o trilho aparece, sem inventar um zero.
    ///   - color: cor do estado (verde/âmbar/vermelho), aplicada à logo e ao preenchimento.
    static func image(glyph: ProviderGlyph, fraction: Double?, color: NSColor) -> NSImage {
        // `NSImage(size:flipped:drawingHandler:)` redesenha na escala da tela em que a imagem
        // for exibida, então a logo e a barra saem nítidas em Retina.
        let image = NSImage(size: imageSize, flipped: false) { bounds in
            let glyphRect = NSRect(
                x: bounds.minX,
                y: bounds.midY - glyphSide / 2,
                width: glyphSide,
                height: glyphSide
            )
            let path = glyph.bezierPath(in: glyphRect)
            path.lineWidth = ProviderGlyph.lineWidth(for: glyphSide)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            color.setStroke()
            path.stroke()

            let barRect = NSRect(
                x: glyphRect.maxX + gap,
                y: bounds.midY - barHeight / 2,
                width: barWidth,
                height: barHeight
            )
            let radius = barHeight / 2

            Theme.NS.track.setFill()
            NSBezierPath(roundedRect: barRect, xRadius: radius, yRadius: radius).fill()

            if let fraction {
                let clamped = min(max(fraction, 0), 1)
                // Abaixo de uma barra redonda inteira não há como desenhar proporção: o mínimo
                // visível é a própria bolinha, e só some de vez quando o uso é zero.
                let filledWidth = clamped > 0 ? max(barHeight, barWidth * clamped) : 0
                if filledWidth > 0 {
                    let filled = NSRect(
                        x: barRect.minX, y: barRect.minY,
                        width: filledWidth, height: barHeight
                    )
                    color.setFill()
                    NSBezierPath(roundedRect: filled, xRadius: radius, yRadius: radius).fill()
                }
            }

            return true
        }
        // A imagem tem cor própria (o estado do uso), então não pode ser recolorida pelo tema
        // da barra de menu.
        image.isTemplate = false
        return image
    }
}
