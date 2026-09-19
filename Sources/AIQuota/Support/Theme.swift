import AppKit
import SwiftUI

/// Único lugar do app onde valores visuais brutos existem. Todo o resto das views referencia
/// constantes nomeadas daqui — nenhum hexadecimal solto espalhado pela interface.
///
/// Pele REDLINE (print de referência do usuário, set/2026): preto absoluto, hairline fria
/// `#1F2937`, acento vermelho `#EF4444` e semáforo Tailwind nas barras de cota. DevTerm/PilotDeck
/// deram a ESTRUTURA que continua de pé (mono em tudo, caixa alta com tracking, densidade); o que
/// esta paleta substitui é só a pele cinza-azulada do PilotDeck.
///
/// Os tons vêm da escala Tailwind, como no print: gray-800 `#1F2937` para linha e trilho,
/// gray-600 `#4B5563` para borda de botão fantasma, gray-400 `#9CA3AF` para texto secundário,
/// red-500 `#EF4444` como acento, green-500/yellow-500/red-500 no semáforo.
enum Theme {

    // MARK: - Cores (paleta do print de referência)

    /// Fundo (canvas) — preto absoluto, como no print.
    static let bg = Color(hex: 0x000000)
    /// Superfície de card: um degrau mínimo acima do preto, o suficiente para a borda fazer o
    /// trabalho de desenhar a caixa sem o card "acender".
    static let surface = Color(hex: 0x0A0A0A)

    /// Texto primário.
    static let ink = Color(hex: 0xFFFFFF)
    /// Texto secundário (gray-400).
    static let inkDim = Color(hex: 0x9CA3AF)
    /// Um passo abaixo do secundário, para texto de apoio que não deve competir (gray-500).
    static let inkMuted = Color(hex: 0x6B7280)
    /// Texto apagado: provedor sem dado, caminhos de arquivo, traços de ausência (gray-600).
    static let inkFaint = Color(hex: 0x4B5563)

    /// O acento da marca: vermelho REDLINE. Usado na segunda palavra da assinatura e no botão
    /// primário — e em mais nada, para continuar valendo como acento.
    static let accent = Color(hex: 0xEF4444)
    /// Cinza médio de foco/realce.
    static let focus = Color(hex: 0x9CA3AF)
    /// Vermelho de alarme. Mesmo hex do acento de propósito: no print, cota estourada e botão
    /// primário são o mesmo vermelho — o contexto (barra vs. botão) é que separa os dois.
    static let danger = Color(hex: 0xEF4444)
    /// O pontinho antes da logo no cabeçalho de cada provedor — puramente decorativo (marca de
    /// lista, não estado), por isso é uma constante própria em vez de reaproveitar `danger`.
    static let groupDot = Color(hex: 0xEF4444)

    /// Semáforo de verdade — verde/âmbar/vermelho — nas janelas de cota (5h, semanal etc.): cada
    /// janela é um limite real que estoura, e a cor É a informação.
    static let calm = Color(hex: 0x22C55E)
    static let warn = Color(hex: 0xEAB308)
    /// Azul-esverdeado da paleta — reservado para acentos que não sejam nível de uso.
    static let teal = Color(hex: 0x27A99D)
    /// Azul-violeta da paleta — idem (ex.: cabeçalho de um provedor "diferente" como o Kimi).
    static let violet = Color(hex: 0x8C8BE7)

    /// A borda/divisória e o trilho das barras: a hairline fria do REDLINE (gray-800). No print
    /// os dois são o MESMO tom — a moldura do card e a trilha da barra pertencem à mesma camada.
    static let line = Color(hex: 0x1F2937)
    /// Um degrau acima da linha, para hover e borda de botão fantasma (gray-600).
    static let lineStrong = Color(hex: 0x4B5563)
    static let track = Color(hex: 0x1F2937)
    /// O fundo levemente avermelhado da aba ativa (`#0E0404` no print): o acento aparecendo como
    /// superfície, não como traço.
    static let accentWash = Color(hex: 0x0E0404)

    // MARK: - Cores em AppKit (NSStatusItem)

    enum NS {
        static let bg = NSColor(hex: 0x000000)
        static let accent = NSColor(hex: 0xEF4444)
        static let focus = NSColor(hex: 0x9CA3AF)
        static let danger = NSColor(hex: 0xEF4444)
        static let calm = NSColor(hex: 0x22C55E)
        static let warn = NSColor(hex: 0xEAB308)
        static let inkDim = NSColor(hex: 0x9CA3AF)
        static let inkFaint = NSColor(hex: 0x4B5563)
        /// Trilho da barrinha da barra de menu: mais claro que o trilho do painel, porque na
        /// barra de menu (bem menor) precisa de mais presença para o vazio ficar legível.
        static let track = NSColor(hex: 0x374151)
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
        /// Rótulo em MAIÚSCULAS (cabeçalho).
        static let label: CGFloat = 10
        /// Texto de apoio: caminhos, resumo, ações do rodapé.
        static let micro: CGFloat = 9
        /// Nome da IA e percentual — o texto principal do painel.
        static let small: CGFloat = 11
        static let body: CGFloat = 12
    }

    /// `letter-spacing` em `em`, convertido para pontos por `tracking(_:at:)`.
    enum Em {
        /// 0.12em — o tracking de `.brand`/`.foot` do PilotDeck, mais contido que os 0.22em do
        /// DevTerm.
        static let label: CGFloat = 0.12
        static let subtle: CGFloat = 0.04
    }

    static func tracking(_ em: CGFloat, at size: CGFloat) -> CGFloat { em * size }

    // MARK: - Forma (§3)

    enum Radius {
        /// Raio de painel do PilotDeck.
        static let panel: CGFloat = 12
        /// Raio de controle (campo, botão).
        static let control: CGFloat = 8
        /// Raio dos cards da janela de Ajustes — medido em 8 no print.
        static let card: CGFloat = 8
        /// Recorte da logo da IA e indicadores pequenos.
        static let logo: CGFloat = 4
    }

    enum Metric {
        /// Espessura da borda. Continua 1px; o que mudou foi a cor ficar visível.
        static let border: CGFloat = 1
        /// ~290px do print de referência, com 12px de margem interna.
        static let panelWidth: CGFloat = 292

        /// Geometria da janela de Ajustes — toda MEDIDA do print de referência (680×656), não
        /// estimada: a moldura, o intervalo entre cards e as quatro colunas de uma linha de cota.
        enum Settings {
            static let width: CGFloat = 680
            static let height: CGFloat = 656
            /// Margem da janela até a borda do card (21px no print).
            static let gutter: CGFloat = 20
            static let cardPadding: CGFloat = 13
            static let cardGap: CGFloat = 16
            /// Barra de 4px de altura, linhas a cada 16px (290 → 306 → 322 no print).
            static let barHeight: CGFloat = 4
            static let barRowGap: CGFloat = 3
            /// Colunas: rótulo 34→114, percentual termina em 596, reset termina em 639.
            static let barLabelWidth: CGFloat = 81
            static let barPercentWidth: CGFloat = 54
            static let barResetWidth: CGFloat = 84
        }
        static let padding: CGFloat = 12
        /// Lado da logo da IA no painel.
        static let logoSide: CGFloat = 14
        static let usageBarWidth: CGFloat = 75
        static let usageBarHeight: CGFloat = 4
        /// Largura fixa da coluna do percentual, para os números não dançarem entre linhas.
        static let percentColumnWidth: CGFloat = 32

        /// Recuo das linhas de janela sob o cabeçalho do provedor — alinha com o texto do nome,
        /// não com a logo.
        static let windowIndent: CGFloat = logoSide + 8
        /// Largura fixa do rótulo da janela ("5H", "SEMANAL"...), para a barra começar sempre na
        /// mesma coluna independente do tamanho do rótulo.
        static let windowLabelWidth: CGFloat = 54
        /// Largura fixa do texto de reset ("em 4d10h", "resetou"), alinhado à direita.
        static let resetColumnWidth: CGFloat = 64
        static let windowRowHeight: CGFloat = 18
    }

    // MARK: - Movimento (§4)

    enum Motion {
        /// 140ms com curva elástica — hover e estados de botão.
        static let fast = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.14)
        /// 180ms — transição padrão de cor/borda.
        static let standard = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.18)
        /// Troca de tela (painel ⇄ provedores).
        static let screen = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.24)
        /// Barra de uso indo até o novo valor.
        static let bar = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.3)
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
