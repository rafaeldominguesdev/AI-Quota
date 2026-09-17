import AppKit
import SwiftUI

/// Único lugar do app onde valores visuais brutos existem. Todo o resto das views referencia
/// constantes nomeadas daqui — nenhum hexadecimal solto espalhado pela interface.
///
/// Os valores vêm de `docs/DEVTERM-STYLE.md`: preto absoluto, hairlines quase invisíveis,
/// monoespaçada em tudo, vermelho como marca (não como alarme).
enum Theme {

    // MARK: - Cores (docs/DEVTERM-STYLE.md §1)

    /// Fundo principal (canvas) — preto absoluto, sem material translúcido.
    static let bg = Color(hex: 0x000000)
    /// Fundo muito sutilmente elevado.
    static let bgSoft = Color(hex: 0x050505)
    /// Superfícies: cards, trilhos, campos.
    static let surface = Color(hex: 0x08080A)

    static let ink = Color(hex: 0xFFFFFF)
    static let inkDim = Color(hex: 0x9CA3AF)
    static let inkMuted = Color(hex: 0x6B7280)
    static let inkFaint = Color(hex: 0x4B5563)

    /// Acento principal: a marca. Aparece em foco e estado ativo, nunca como alarme.
    static let primary = Color(hex: 0xFF3B3B)
    static let primaryDim = Color(hex: 0xC73030)
    /// Acento secundário: usado no dado mais valioso do app (limite oficial do provedor).
    static let secondary = Color(hex: 0x1FBCD8)
    static let secondaryDim = Color(hex: 0x178EA3)
    static let success = Color(hex: 0x3ECF8E)
    /// Verde fosco de telemetria — contador de tokens, que não deve competir com o resto.
    static let tok = Color(hex: 0x8FD6B4)
    /// Âmbar "papel" de rótulo/função. Também o estado de atenção.
    static let role = Color(hex: 0xE0A33C)
    static let danger = Color(hex: 0xFF5A5F)

    /// Linha fina padrão: quase invisível no preto, mas é a assinatura do visual.
    static let hairline = Color(hex: 0x161618)
    /// Linha fina em hover/destaque.
    static let hairlineStrong = Color(hex: 0x242428)
    /// Cinza quente de "passado/histórico" — usado no tempo já decorrido da janela.
    static let rain = Color(hex: 0x4A3A3E)

    // MARK: - Cores em AppKit (NSStatusItem)

    enum NS {
        static let ink = NSColor(hex: 0xFFFFFF)
        static let inkFaint = NSColor(hex: 0x4B5563)
        static let track = NSColor(hex: 0x3A3A3E)
        static let success = NSColor(hex: 0x3ECF8E)
        static let role = NSColor(hex: 0xE0A33C)
        static let danger = NSColor(hex: 0xFF5A5F)
        static let secondary = NSColor(hex: 0x1FBCD8)
    }

    // MARK: - Tipografia (§2)

    /// Famílias tentadas em ordem: JetBrains Mono (se o usuário tiver instalada), SF Mono,
    /// e por fim a monoespaçada do sistema via `design: .monospaced`.
    private static let monoFamily: String? = {
        let available = Set(NSFontManager.shared.availableFontFamilies)
        for candidate in ["JetBrains Mono", "SF Mono", "Menlo"] where available.contains(candidate) {
            return candidate
        }
        return nil
    }()

    /// Fonte monoespaçada do app. Usada em 100% da interface — é terminal, é código, é mono.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        guard let monoFamily else {
            return .system(size: size, weight: weight, design: .monospaced)
        }
        return .custom(monoFamily, fixedSize: size).weight(weight)
    }

    /// Equivalente AppKit, para o título do NSStatusItem.
    static func nsMono(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        if let monoFamily,
           let descriptor = NSFontManager.shared.availableMembers(ofFontFamily: monoFamily)?.first,
           let name = descriptor.first as? String,
           let font = NSFont(name: name, size: size) {
            return NSFontManager.shared.convert(font, toHaveTrait: weight >= .semibold ? .boldFontMask : [])
        }
        return .monospacedSystemFont(ofSize: size, weight: weight)
    }

    // MARK: - Escala de texto

    enum Size {
        /// Rótulo de seção em MAIÚSCULAS.
        static let label: CGFloat = 10
        static let micro: CGFloat = 9
        static let small: CGFloat = 11
        static let body: CGFloat = 12
        static let value: CGFloat = 14
        static let countdown: CGFloat = 20
        static let gauge: CGFloat = 30
    }

    /// `letter-spacing` em `em`, convertido para pontos por `tracking(_:at:)`.
    enum Em {
        /// 0.22em — o tracking largo dos rótulos em caixa alta. É o que mais entrega a identidade.
        static let label: CGFloat = 0.22
        /// 0.08em — botões e texto de marca.
        static let button: CGFloat = 0.08
        static let subtle: CGFloat = 0.04
    }

    static func tracking(_ em: CGFloat, at size: CGFloat) -> CGFloat { em * size }

    // MARK: - Forma (§3)

    enum Radius {
        /// Cards, controles, campos.
        static let card: CGFloat = 6
        /// Elementos flutuantes (o popover).
        static let pop: CGFloat = 8
        /// Badges e indicadores quadrados.
        static let small: CGFloat = 3
    }

    enum Metric {
        static let hairline: CGFloat = 1
        static let panelWidth: CGFloat = 380
        /// Altura máxima do corpo rolável antes de o painel parar de crescer.
        static let bodyMaxHeight: CGFloat = 520
        static let padding: CGFloat = 14
        static let heroGauge: CGFloat = 110
    }

    // MARK: - Movimento (§4)

    enum Motion {
        /// 140ms com curva elástica — hover e estados de botão.
        static let fast = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.14)
        /// 180ms — transição padrão de cor/borda.
        static let standard = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.18)
        /// Expansão de linha de provedor.
        static let expand = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.3)
        /// Troca de tela (painel ⇄ provedores).
        static let screen = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.3)
        /// Anel do medidor se movendo até o novo valor.
        static let gauge = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.7)
        /// Números "contando" até o valor.
        static let count = Animation.easeOut(duration: 0.7)
        /// Ponto de "ao vivo" pulsando.
        static let pulse = Animation.easeInOut(duration: 1.1).repeatForever(autoreverses: true)
    }
}

// MARK: - Hex

extension Color {
    /// Inicializa a partir de um literal 0xRRGGBB, do jeito que o design system escreve.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
