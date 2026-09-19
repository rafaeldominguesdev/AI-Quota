import AppKit

/// O indicador da barra de menu: uma logo por IA conectada, e à direita dela uma barrinha +
/// rótulo de tempo por janela de cota, empilhadas verticalmente (sessão em cima, semanal
/// embaixo) em vez de lado a lado — é o formato que o usuário pediu, imitando um mini painel de
/// duas linhas por IA. Um traço fino separa uma IA da próxima.
enum MenuBarIndicator {

    private static let logoSide: CGFloat = 15
    private static let logoCornerRadius: CGFloat = 3
    private static let barWidth: CGFloat = 17
    private static let barHeight: CGFloat = 4
    /// Espaço entre a logo e a pilha de barrinhas da IA.
    private static let logoToStackGap: CGFloat = 4
    /// Espaço entre a barrinha e seu rótulo de tempo.
    private static let barToLabelGap: CGFloat = 4
    /// Espaço vertical entre uma linha (barra+rótulo) e a próxima, na mesma IA.
    private static let rowSpacing: CGFloat = 2.5
    /// Espaço de cada lado do traço divisor entre IAs.
    private static let dividerPadding: CGFloat = 6
    private static let dividerWidth: CGFloat = 1

    private static var labelFont: NSFont { Theme.nsMono(11, .medium) }

    /// Uma janela de cota dentro de uma IA: sua barrinha (`nil` = só o trilho) e o texto curto ao
    /// lado ("2d", "4h"...), quando há uma data de reset para mostrar.
    struct Window {
        let fraction: Double?
        let color: NSColor
        let label: String?

        init(fraction: Double?, color: NSColor, label: String? = nil) {
            self.fraction = fraction
            self.color = color
            self.label = label
        }
    }

    /// Uma IA e as janelas de cota que ela reporta, na ordem em que devem empilhar (a primeira
    /// vai em cima).
    struct Group {
        let providerId: String
        let windows: [Window]
    }

    private static func labelAttributes(color: NSColor) -> [NSAttributedString.Key: Any] {
        [.font: labelFont, .foregroundColor: color, .kern: 0.2]
    }

    private static func labelSize(_ text: String) -> NSSize {
        (text as NSString).size(withAttributes: labelAttributes(color: .white))
    }

    /// Altura de uma linha: a barra sozinha não precisa de tanto, quem manda é a altura do texto.
    private static func rowHeight(_ window: Window) -> CGFloat {
        guard let label = window.label else { return barHeight }
        return max(barHeight, labelSize(label).height)
    }

    private static func rowWidth(_ window: Window) -> CGFloat {
        var width = barWidth
        if let label = window.label {
            width += barToLabelGap + labelSize(label).width
        }
        return width
    }

    private static func stackHeight(_ group: Group) -> CGFloat {
        guard !group.windows.isEmpty else { return 0 }
        let rows = group.windows.reduce(CGFloat(0)) { $0 + rowHeight($1) }
        return rows + CGFloat(group.windows.count - 1) * rowSpacing
    }

    private static func stackWidth(_ group: Group) -> CGFloat {
        group.windows.map(rowWidth).max() ?? 0
    }

    private static func groupWidth(_ group: Group) -> CGFloat {
        guard !group.windows.isEmpty else { return logoSide }
        return logoSide + logoToStackGap + stackWidth(group)
    }

    private static func groupHeight(_ group: Group) -> CGFloat {
        max(logoSide, stackHeight(group))
    }

    static func imageSize(groups: [Group]) -> NSSize {
        guard !groups.isEmpty else { return NSSize(width: logoSide, height: logoSide) }
        var width: CGFloat = 0
        var height: CGFloat = 0
        for (index, group) in groups.enumerated() {
            if index > 0 { width += dividerPadding * 2 + dividerWidth }
            width += groupWidth(group)
            height = max(height, groupHeight(group))
        }
        return NSSize(width: width, height: height)
    }

    /// - Parameter groups: uma por IA conectada, na ordem em que devem aparecer da esquerda para
    ///   a direita. Vazio cai num único trilho apagado, para a barra de menu nunca ficar sem
    ///   ícone algum enquanto a primeira varredura não termina.
    static func image(groups: [Group]) -> NSImage {
        let groups = groups.isEmpty
            ? [Group(providerId: "", windows: [Window(fraction: nil, color: Theme.NS.inkFaint)])]
            : groups
        let size = imageSize(groups: groups)

        // `NSImage(size:flipped:drawingHandler:)` redesenha na escala da tela em que a imagem
        // for exibida, então logo, barras e texto saem nítidos em Retina.
        let image = NSImage(size: size, flipped: false) { bounds in
            var x = bounds.minX
            for (index, group) in groups.enumerated() {
                if index > 0 {
                    x += dividerPadding
                    drawDivider(at: x, bounds: bounds)
                    x += dividerWidth + dividerPadding
                }
                x = draw(group, originX: x, bounds: bounds)
            }
            return true
        }
        // A imagem tem cor própria (o estado do uso), então não pode ser recolorida pelo tema
        // da barra de menu.
        image.isTemplate = false
        return image
    }

    /// Encolhe um pouco a marca de alguns provedores na barra de menu. O Antigravity é o caso:
    /// o "A" ocupa muita largura e pedia menos presença ao lado das outras.
    private static func logoScale(for providerId: String) -> CGFloat {
        providerId.hasPrefix("antigravity") ? 0.8 : 1
    }

    /// Encaixa a imagem no slot preservando a proporção (aspect-fit), aplicando `scale` e
    /// centralizando — sem espremer um logotipo retangular num quadrado.
    private static func logoDrawRect(_ image: NSImage, in slot: NSRect, scale: CGFloat) -> NSRect {
        let box = slot.insetBy(dx: slot.width * (1 - scale) / 2, dy: slot.height * (1 - scale) / 2)
        let size = image.size
        guard size.width > 0, size.height > 0 else { return box }
        let ratio = min(box.width / size.width, box.height / size.height)
        let w = size.width * ratio, h = size.height * ratio
        return NSRect(x: box.midX - w / 2, y: box.midY - h / 2, width: w, height: h)
    }

    private static func drawDivider(at x: CGFloat, bounds: NSRect) {
        let height = logoSide - 2
        let rect = NSRect(x: x, y: bounds.midY - height / 2, width: dividerWidth, height: height)
        Theme.NS.track.setFill()
        rect.fill()
    }

    /// Desenha uma IA inteira a partir de `originX` e devolve o x logo depois dela, para o
    /// chamador saber onde começar o próximo elemento (divisor ou grupo seguinte).
    @discardableResult
    private static func draw(_ group: Group, originX: CGFloat, bounds: NSRect) -> CGFloat {
        let logo = ProviderLogo.image(for: group.providerId)
        let glyph = ProviderGlyph.forProvider(id: group.providerId)

        let glyphRect = NSRect(
            x: originX,
            y: bounds.midY - logoSide / 2,
            width: logoSide,
            height: logoSide
        )

        if let logo {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.imageInterpolation = .high
            // Desenha respeitando a proporção da imagem, centralizado no slot, com um ajuste de
            // escala por provedor. O "A" do Antigravity é bem mais largo que alto — esticá-lo num
            // quadrado o fazia parecer grande demais; aqui ele entra menor e sem distorção.
            logo.draw(in: logoDrawRect(logo, in: glyphRect, scale: logoScale(for: group.providerId)))
            NSGraphicsContext.restoreGraphicsState()
        } else {
            let fallbackColor = group.windows.first?.color ?? Theme.NS.inkFaint
            let path = glyph.bezierPath(in: glyphRect)
            path.lineWidth = ProviderGlyph.lineWidth(for: logoSide)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            fallbackColor.setStroke()
            path.stroke()
        }

        guard !group.windows.isEmpty else { return glyphRect.maxX }

        let x = glyphRect.maxX + logoToStackGap
        // Empilha de cima para baixo: a primeira janela (sessão) fica no topo, a próxima
        // (semanal) embaixo dela.
        var rowTop = bounds.midY + stackHeight(group) / 2
        for window in group.windows {
            let height = rowHeight(window)
            let rowMidY = rowTop - height / 2

            let barRect = NSRect(x: x, y: rowMidY - barHeight / 2, width: barWidth, height: barHeight)
            let radius = barHeight / 2

            Theme.NS.track.setFill()
            NSBezierPath(roundedRect: barRect, xRadius: radius, yRadius: radius).fill()

            if let fraction = window.fraction {
                let clamped = min(max(fraction, 0), 1)
                // Abaixo de uma barra redonda inteira não há como desenhar proporção: o mínimo
                // visível é a própria bolinha, e só some de vez quando o uso é zero.
                let filledWidth = clamped > 0 ? max(barHeight, barWidth * clamped) : 0
                if filledWidth > 0 {
                    let filled = NSRect(x: barRect.minX, y: barRect.minY, width: filledWidth, height: barHeight)
                    window.color.setFill()
                    NSBezierPath(roundedRect: filled, xRadius: radius, yRadius: radius).fill()
                }
            }

            if let label = window.label {
                let size = labelSize(label)
                let textRect = NSRect(
                    x: barRect.maxX + barToLabelGap,
                    y: rowMidY - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                (label as NSString).draw(in: textRect, withAttributes: labelAttributes(color: window.color))
            }

            rowTop -= height + rowSpacing
        }

        return x + stackWidth(group)
    }
}
