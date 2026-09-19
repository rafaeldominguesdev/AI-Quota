import AppKit
import SwiftUI

/// Resolve a marca de cada IA, em três degraus:
///
///   1. `~/.config/ai-quota/logos/<id>.(png|jpg|jpeg|webp|svg)` — o usuário solta o arquivo lá e
///      qualquer IA que ele adicionou pelo `providers.json` ganha logo, sem recompilar nada;
///   2. o recurso embutido no app, para as marcas que já vêm com ele;
///   3. o glifo desenhado em `ProviderGlyph`, para quem não tem nenhuma das duas.
///
/// O resultado é cacheado: a resolução mexe em disco e a barra de menu redesenha a cada
/// varredura.
enum ProviderLogo {
    /// Onde o usuário coloca as logos das IAs que ele mesmo adicionou.
    static let userDirectory = URL(
        fileURLWithPath: (NSString(string: "~/.config/ai-quota/logos")).expandingTildeInPath
    )

    private static let searchedExtensions = ["png", "svg", "webp", "jpg", "jpeg"]

    /// Nome do recurso embutido de cada provedor. Só existe para as marcas que o app carrega;
        private static let bundledResources: [String: String] = [
        "claude-code": "claude-code.svg",
        "codex": "codex.svg",
        "grok": "grok.png",
        "cursor": "cursor.png",
        // Disponíveis para quem adicionar esses provedores pelo providers.json.
        "deepseek": "deepseek.jpg",
        "meta": "meta.png",
        "antigravity": "antigravity.png"
    ]

    /// `nil` quando não há imagem para o provedor e a UI deve desenhar o glifo.
    static func image(for providerId: String) -> NSImage? {
        if let cached = cache.withLock({ $0[providerId] }) {
            return cached.image
        }
        let resolved = resolve(providerId: providerId)
        cache.withLock { $0[providerId] = Box(image: resolved) }
        return resolved
    }

    /// Esvazia o cache, para uma logo recém-colocada em `~/.config/ai-quota/logos` aparecer sem
    /// reiniciar o app.
    static func invalidateCache() {
        cache.withLock { $0.removeAll() }
    }

    private static func resolve(providerId: String) -> NSImage? {
        for ext in searchedExtensions {
            let candidate = userDirectory.appendingPathComponent("\(providerId).\(ext)")
            if FileManager.default.fileExists(atPath: candidate.path),
               let image = NSImage(contentsOf: candidate) {
                return image
            }
        }

        // Contas extras descobertas por `MultiAccountDiscovery` usam um id composto ("codex-work",
        // "claude-code-pessoal") — cai na mesma logo da conta padrão por prefixo, em vez de virar
        // glifo só porque o id não bate igualzinho.
        guard let resource = bundledResources[providerId]
                ?? bundledResources.first(where: { providerId.hasPrefix($0.key) })?.value else {
            return nil
        }
        let name = (resource as NSString).deletingPathExtension
        let ext = (resource as NSString).pathExtension
        guard let url = Bundle.module.url(forResource: "Resources/providers/\(name)", withExtension: ext)
                ?? Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources/providers") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    // MARK: - Cache

    /// `NSImage` não é `Sendable`, então o cache guarda cada uma dentro de uma caixa e o acesso
    /// passa por um mutex — o carregamento pode ser pedido tanto pela UI quanto pelo redesenho
    /// do NSStatusItem.
    private struct Box: @unchecked Sendable {
        let image: NSImage?
    }

    private static let cache = Mutex<[String: Box]>([:])
}

/// Mutex mínimo para o cache de logos. `OSAllocatedUnfairLock` resolveria, mas exige importar
/// `os` e não aceita um valor genérico com a mesma clareza.
private final class Mutex<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.value = value
    }

    func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

// MARK: - A logo no painel

/// A marca da IA no painel: a imagem real quando existe, recortada num quadrado de canto
/// arredondado com uma borda fina por cima — é a borda do PilotDeck que assenta um logotipo
/// colorido (ou de fundo claro) numa interface cinza escura. Sem imagem, cai no glifo desenhado.
struct ProviderLogoView: View {
    let providerId: String
    /// Cor do glifo, quando o fallback desenhado entra em cena.
    let glyphColor: Color
    var side: CGFloat = Theme.Metric.logoSide

    var body: some View {
        if let image = ProviderLogo.image(for: providerId) {
            // Só o ícone: sem quadrado nem borda em volta, e `.fit` para não cortar nada. `.high`
            // mantém a marca nítida ao ampliar (as fontes têm de 200 a 1200 px).
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: side, height: side)
        } else {
            ProviderGlyphView(
                glyph: ProviderGlyph.forProvider(id: providerId),
                color: glyphColor,
                side: side
            )
        }
    }
}
