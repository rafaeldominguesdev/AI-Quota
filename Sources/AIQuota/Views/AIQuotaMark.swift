import SwiftUI

/// A marca do AI Quota: o conta-giros, desenhado como VETOR em vez da bitmap do ícone.
///
/// Os ângulos vieram medidos da logo original por varredura polar, não estimados: o arco vai de
/// 136° a 403° (varredura de 267°, com o vão embaixo), o ponteiro aponta para 303° — já dentro da
/// zona vermelha, que é de onde vem o nome REDLINE — e há 27 marcações de 10 em 10 graus.
///
/// Duas liberdades deliberadas em relação ao original, pelo tamanho de uso (18–22pt no cabeçalho):
/// a espessura do arco sobe de 7,3% do raio para 16%, porque na escala real 0,073 daria meio ponto
/// e sumiria; e as marcações só aparecem quando há pixel para elas — abaixo disso viram sujeira.
/// Ver `tickDetail`.
struct AIQuotaMark: View {
    var side: CGFloat = 20
    var color: Color = Theme.accent

    /// Onde o arco começa e termina, em graus (0° às 3h, crescendo no sentido horário porque o
    /// eixo y da tela aponta para baixo).
    private static let arcStart: Double = 136
    private static let arcEnd: Double = 403
    private static let needleAngle: Double = 303

    /// Quantas marcações desenhar, decidido pelo raio em pontos: nenhuma quando não há pixel,
    /// só as principais num tamanho intermediário, todas quando a marca é grande.
    private enum TickDetail { case none, major, all }

    private func tickDetail(radius: CGFloat) -> TickDetail {
        if radius >= 26 { return .all }
        if radius >= 11 { return .major }
        return .none
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height * 0.54)
            let radius = min(size.width, size.height) * 0.42
            let stroke = max(1.1, radius * 0.16)

            let arc = Path { path in
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(Self.arcStart),
                    endAngle: .degrees(Self.arcEnd),
                    clockwise: false
                )
            }

            // O brilho vermelho do original, em duas passadas: um halo borrado por baixo e o
            // traço nítido por cima. Sem o halo a marca fica chapada demais no preto.
            var glow = context
            glow.addFilter(.blur(radius: min(radius * 0.18, 6)))
            glow.stroke(arc, with: .color(color.opacity(0.45)), style: StrokeStyle(lineWidth: stroke, lineCap: .round))

            context.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: stroke, lineCap: .round))

            // Marcações, para dentro do arco.
            let detail = tickDetail(radius: radius)
            if detail != .none {
                let step: Double = detail == .all ? 10 : 30
                let outer = radius - stroke * 0.85
                let ticks = Path { path in
                    var angle = Self.arcStart + step / 2
                    while angle < Self.arcEnd {
                        let isMajor = Int((angle - Self.arcStart).rounded()) % 30 == 15
                        let length = radius * (isMajor ? 0.17 : 0.10)
                        let radians = Angle.degrees(angle).radians
                        let unit = CGPoint(x: cos(radians), y: sin(radians))
                        path.move(to: CGPoint(x: center.x + unit.x * outer, y: center.y + unit.y * outer))
                        path.addLine(
                            to: CGPoint(
                                x: center.x + unit.x * (outer - length),
                                y: center.y + unit.y * (outer - length)
                            )
                        )
                        angle += step
                    }
                }
                context.stroke(
                    ticks,
                    with: .color(color.opacity(0.85)),
                    style: StrokeStyle(lineWidth: max(0.7, radius * 0.055), lineCap: .butt)
                )
            }

            // Ponteiro: do cubo até perto do arco, e o ponto quente onde ele encosta na escala —
            // é esse brilho que dá a leitura de "estourando o limite".
            let needleRadians = Angle.degrees(Self.needleAngle).radians
            let needleUnit = CGPoint(x: cos(needleRadians), y: sin(needleRadians))
            let needleTip = CGPoint(
                x: center.x + needleUnit.x * radius * 0.78,
                y: center.y + needleUnit.y * radius * 0.78
            )
            let needle = Path { path in
                path.move(to: center)
                path.addLine(to: needleTip)
            }
            context.stroke(
                needle,
                with: .color(color),
                style: StrokeStyle(lineWidth: max(1, radius * 0.12), lineCap: .round)
            )

            let hubSide = radius * 0.34
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - hubSide / 2, y: center.y - hubSide / 2,
                    width: hubSide, height: hubSide
                )),
                with: .color(color)
            )

            if radius >= 11 {
                var hot = context
                hot.addFilter(.blur(radius: min(max(0.8, radius * 0.14), 7)))
                let hotSide = min(radius * 0.24, 14)
                let hotCenter = CGPoint(
                    x: center.x + needleUnit.x * radius,
                    y: center.y + needleUnit.y * radius
                )
                hot.fill(
                    Path(ellipseIn: CGRect(
                        x: hotCenter.x - hotSide / 2, y: hotCenter.y - hotSide / 2,
                        width: hotSide, height: hotSide
                    )),
                    with: .color(.white.opacity(0.62))
                )
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}
