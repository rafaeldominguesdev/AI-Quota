import AppKit
import SwiftUI

/// Único lugar do app onde valores visuais brutos existem. Todo o resto das views referencia
/// constantes nomeadas daqui — nenhum hexadecimal solto espalhado pela interface.
///
/// Os valores vêm de `docs/PILOTDECK-STYLE.md`: cinza-azulado escuro em degraus, borda visível
/// desenhando cada caixa, acento NEUTRO (cinza quase branco) em vez de cor de marca, e vermelho
/// dessaturado reservado ao alarme. A estrutura (mono, caixa alta, densidade) vem do DevTerm; a
/// pele é do PilotDeck.
enum Theme {

    // MARK: - Cores (docs/PILOTDECK-STYLE.md §1)

    /// Fundo (canvas). Preto quase liso, com uma pitada azulada — paleta pedida pelo usuário
    /// para o painel em estilo TUI.
    static let bg = Color(hex: 0x0D1117)
    /// Superfície um degrau acima do fundo — e aqui o degrau se vê.
    static let surface = Color(hex: 0x12161B)

    /// Texto primário.
    static let ink = Color(hex: 0xD6D6D6)
    /// Texto secundário.
    static let inkDim = Color(hex: 0x858585)
    /// Um passo abaixo do secundário, para texto de apoio que não deve competir.
    static let inkMuted = Color(hex: 0x6E747D)
    /// Texto apagado: provedor sem dado, caminhos de arquivo, traços de ausência.
    static let inkFaint = Color(hex: 0x555B63)

    /// Cinza muito claro, quase branco. É acento por LUMINÂNCIA, não por cor.
    static let accent = Color(hex: 0xD7DBDF)
    /// Cinza médio de foco/realce.
    static let focus = Color(hex: 0x9AA3AD)
    /// Vermelho de alarme — só aparece quando há problema de verdade.
    static let danger = Color(hex: 0xE05261)
    /// O quadradinho antes da logo no cabeçalho de cada provedor — puramente decorativo (marca
    /// de lista, não estado), por isso é uma constante própria em vez de reaproveitar `danger`.
    static let groupDot = Color(hex: 0xE2574C)

    /// Semáforo de verdade — verde/âmbar/vermelho — nas janelas de cota (5h, semanal etc.): cada
    /// janela é um limite real que estoura, e a cor É a informação.
    static let calm = Color(hex: 0x36D17A)
    static let warn = Color(hex: 0xE5C447)
    /// Azul-esverdeado da paleta pedida — reservado para acentos que não sejam nível de uso.
    static let teal = Color(hex: 0x27A99D)
    /// Roxo/azul da paleta pedida — idem.
    static let violet = Color(hex: 0x8B7CFF)

    /// A borda/divisória: linha discreta separando blocos.
    static let line = Color(hex: 0x28303A)
    /// Um degrau acima da linha, para hover.
    static let lineStrong = Color(hex: 0x323C48)
    /// Trilho das barrinhas de uso — mais escuro que a divisória, para a barra ficar legível sem
    /// competir com as linhas do painel.
    static let track = Color(hex: 0x1F2933)

    // MARK: - Cores em AppKit (NSStatusItem)

    enum NS {
        static let bg = NSColor(hex: 0x0D1117)
        static let accent = NSColor(hex: 0xD7DBDF)
        static let focus = NSColor(hex: 0x9AA3AD)
        static let danger = NSColor(hex: 0xE05261)
        static let calm = NSColor(hex: 0x36D17A)
        static let warn = NSColor(hex: 0xE5C447)
        static let inkDim = NSColor(hex: 0x858585)
        static let inkFaint = NSColor(hex: 0x555B63)
        /// Trilho da barrinha da barra de menu: mais claro que o trilho do painel, porque na
        /// barra de menu (bem menor) precisa de mais presença para o vazio ficar legível.
        static let track = NSColor(hex: 0x323944)
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
        /// Recorte da logo da IA e indicadores pequenos.
        static let logo: CGFloat = 4
    }

    enum Metric {
        /// Espessura da borda. Continua 1px; o que mudou foi a cor ficar visível.
        static let border: CGFloat = 1
        // Aumentados junto com o texto (era 308/16): letras maiores sem mais respiro deixava
        // tudo espremido contra a borda.
        static let panelWidth: CGFloat = 336
        static let padding: CGFloat = 20
        /// Lado da logo da IA no painel.
        static let logoSide: CGFloat = 14
        static let usageBarWidth: CGFloat = 72
        static let usageBarHeight: CGFloat = 4
        /// Largura fixa da coluna do percentual, para os números não dançarem entre linhas.
        static let percentColumnWidth: CGFloat = 40

        /// Recuo das linhas de janela sob o cabeçalho do provedor — alinha com o texto do nome,
        /// não com a logo.
        static let windowIndent: CGFloat = logoSide + 8
        /// Largura fixa do rótulo da janela ("5H", "SEMANAL"...), para a barra começar sempre na
        /// mesma coluna independente do tamanho do rótulo.
        static let windowLabelWidth: CGFloat = 64
        /// Largura fixa do texto de reset ("em 4d10h", "resetou"), alinhado à direita.
        static let resetColumnWidth: CGFloat = 62
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
