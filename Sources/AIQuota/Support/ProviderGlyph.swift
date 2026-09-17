import AppKit
import SwiftUI

/// Marca de cada IA, desenhada aqui em código como forma geométrica simples e genérica — não é
/// logotipo de marca, é um glifo próprio que só precisa ser reconhecível a 12-14pt.
///
/// O glifo é descrito uma única vez em coordenadas normalizadas (0...1, com y crescendo para
/// baixo) e então renderizado em SwiftUI (`Path`) ou em AppKit (`NSBezierPath`, que inverte o y).
/// Assim o mesmo desenho serve o painel e a barra de menu, em qualquer tamanho.
enum ProviderGlyph {
    case sunburst
    case hexagon
    case fourPointStar
    case cross
    case cube
    case circle

    /// Glifo de cada provedor. Provedores customizados (GLM, Qwen, DeepSeek…) caem no círculo.
    static func forProvider(id: String) -> ProviderGlyph {
        switch id {
        case "claude-code": return .sunburst
        case "codex": return .hexagon
        case "gemini": return .fourPointStar
        case "grok": return .cross
        case "cursor": return .cube
        default: return .circle
        }
    }

    /// Espessura do traço, proporcional ao tamanho: o glifo tem que ficar fino a 14pt sem
    /// desaparecer a 12pt.
    static func lineWidth(for side: CGFloat) -> CGFloat {
        max(1, side * 0.09)
    }

    // MARK: - Descrição do desenho

    enum Command {
        case move(CGPoint)
        case line(CGPoint)
        /// Curva quadrática — é o que dá os lados côncavos da estrela.
        case quad(to: CGPoint, control: CGPoint)
        case close
        case ellipse(CGRect)
    }

    var commands: [Command] {
        switch self {
        case .sunburst: return Self.sunburstCommands
        case .hexagon: return Self.polygonCommands(sides: 6, radius: 0.44)
        case .fourPointStar: return Self.fourPointStarCommands
        case .cross: return Self.crossCommands
        case .cube: return Self.cubeCommands
        case .circle: return [.ellipse(CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.84))]
        }
    }

    /// Oito pétalas finas irradiando de um centro vazado.
    private static var sunburstCommands: [Command] {
        let center = CGPoint(x: 0.5, y: 0.5)
        let inner: CGFloat = 0.15
        let outer: CGFloat = 0.47
        return (0..<8).flatMap { index -> [Command] in
            let angle = CGFloat(index) * .pi / 4
            let dx = cos(angle)
            let dy = sin(angle)
            return [
                .move(CGPoint(x: center.x + dx * inner, y: center.y + dy * inner)),
                .line(CGPoint(x: center.x + dx * outer, y: center.y + dy * outer))
            ]
        }
    }

    /// Polígono regular com um vértice apontando para cima.
    private static func polygonCommands(sides: Int, radius: CGFloat) -> [Command] {
        var commands: [Command] = []
        for index in 0..<sides {
            // -90° põe o primeiro vértice no topo.
            let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / CGFloat(sides)
            let point = CGPoint(x: 0.5 + cos(angle) * radius, y: 0.5 + sin(angle) * radius)
            commands.append(index == 0 ? .move(point) : .line(point))
        }
        commands.append(.close)
        return commands
    }

    /// Estrela de quatro pontas: um losango cujos lados curvam para dentro.
    private static var fourPointStarCommands: [Command] {
        let tips = [
            CGPoint(x: 0.5, y: 0.03),
            CGPoint(x: 0.97, y: 0.5),
            CGPoint(x: 0.5, y: 0.97),
            CGPoint(x: 0.03, y: 0.5)
        ]
        // O ponto de controle fica perto do centro, na bissetriz entre duas pontas: é o quanto
        // o lado "afunda".
        let waist: CGFloat = 0.11
        var commands: [Command] = [.move(tips[0])]
        for index in 0..<tips.count {
            let from = tips[index]
            let to = tips[(index + 1) % tips.count]
            let bisector = CGPoint(
                x: (from.x + to.x) / 2 - 0.5,
                y: (from.y + to.y) / 2 - 0.5
            )
            let length = max(0.0001, sqrt(bisector.x * bisector.x + bisector.y * bisector.y))
            let control = CGPoint(
                x: 0.5 + bisector.x / length * waist,
                y: 0.5 + bisector.y / length * waist
            )
            commands.append(.quad(to: to, control: control))
        }
        commands.append(.close)
        return commands
    }

    /// Dois traços retos cruzados.
    private static var crossCommands: [Command] {
        [
            .move(CGPoint(x: 0.14, y: 0.14)),
            .line(CGPoint(x: 0.86, y: 0.86)),
            .move(CGPoint(x: 0.86, y: 0.14)),
            .line(CGPoint(x: 0.14, y: 0.86))
        ]
    }

    /// Losango com três arestas internas saindo do centro — o cubo isométrico de traço fino.
    private static var cubeCommands: [Command] {
        let top = CGPoint(x: 0.5, y: 0.06)
        let right = CGPoint(x: 0.94, y: 0.5)
        let bottom = CGPoint(x: 0.5, y: 0.94)
        let left = CGPoint(x: 0.06, y: 0.5)
        let center = CGPoint(x: 0.5, y: 0.5)
        return [
            .move(top), .line(right), .line(bottom), .line(left), .close,
            .move(center), .line(top),
            .move(center), .line(right),
            .move(center), .line(left)
        ]
    }
}

// MARK: - Renderização em SwiftUI

extension ProviderGlyph {
    /// Converte o desenho normalizado para um `Path` dentro de `rect`.
    func path(in rect: CGRect) -> Path {
        var path = Path()
        func scale(_ point: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
        }

        for command in commands {
            switch command {
            case .move(let point):
                path.move(to: scale(point))
            case .line(let point):
                path.addLine(to: scale(point))
            case .quad(let to, let control):
                path.addQuadCurve(to: scale(to), control: scale(control))
            case .close:
                path.closeSubpath()
            case .ellipse(let box):
                path.addEllipse(in: CGRect(
                    x: rect.minX + box.minX * rect.width,
                    y: rect.minY + box.minY * rect.height,
                    width: box.width * rect.width,
                    height: box.height * rect.height
                ))
            }
        }
        return path
    }
}

/// O glifo como view: um traço fino na cor pedida, escalando com o tamanho recebido.
struct ProviderGlyphView: View {
    let glyph: ProviderGlyph
    let color: Color
    var side: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.stroke(
                glyph.path(in: rect),
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: ProviderGlyph.lineWidth(for: min(size.width, size.height)),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        .frame(width: side, height: side)
    }
}

// MARK: - Renderização em AppKit

extension ProviderGlyph {
    /// `NSBezierPath` equivalente, com o y invertido porque o AppKit desenha de baixo para cima.
    func bezierPath(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        func scale(_ point: CGPoint) -> NSPoint {
            NSPoint(x: rect.minX + point.x * rect.width, y: rect.maxY - point.y * rect.height)
        }

        for command in commands {
            switch command {
            case .move(let point):
                path.move(to: scale(point))
            case .line(let point):
                path.line(to: scale(point))
            case .quad(let to, let control):
                // NSBezierPath só tem curva cúbica: a conversão exata de uma quadrática usa os
                // dois controles a 2/3 do caminho entre cada ponta e o controle original.
                let start = path.currentPoint
                let end = scale(to)
                let q = scale(control)
                path.curve(
                    to: end,
                    controlPoint1: NSPoint(x: start.x + 2.0 / 3 * (q.x - start.x), y: start.y + 2.0 / 3 * (q.y - start.y)),
                    controlPoint2: NSPoint(x: end.x + 2.0 / 3 * (q.x - end.x), y: end.y + 2.0 / 3 * (q.y - end.y))
                )
            case .close:
                path.close()
            case .ellipse(let box):
                path.appendOval(in: NSRect(
                    x: rect.minX + box.minX * rect.width,
                    y: rect.maxY - (box.minY + box.height) * rect.height,
                    width: box.width * rect.width,
                    height: box.height * rect.height
                ))
            }
        }
        return path
    }
}
