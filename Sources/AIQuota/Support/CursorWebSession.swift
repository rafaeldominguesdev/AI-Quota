import AppKit
import WebKit

/// Sessão de navegador PRÓPRIA do app pra ler a cota real do Cursor na web.
///
/// `cursor-agent login` (CLI) e o login do site são sistemas separados — a CLI nunca dá acesso ao
/// dashboard. A única forma honesta de ler aquele "% used" sem tocar em credencial de outro app
/// (Chrome, Keychain) é a PESSOA logar uma vez dentro de um WKWebView deste app; a partir daí a
/// sessão fica guardada no cofre de cookies do próprio processo do AI Quota, igual qualquer app
/// que embute login web (nada sai daqui, nada entra de fora).
///
/// Não existe endpoint de API pra esse número (confirmado: as 161 requisições da página não têm
/// nenhuma chamada de dado separada — o valor já vem pronto dentro do HTML renderizado pelo
/// servidor). Por isso a leitura é literalmente carregar a página inteira num WKWebView escondido
/// e procurar o texto "N% used" no conteúdo renderizado.
@MainActor
final class CursorWebSession: NSObject {
    static let shared = CursorWebSession()

    private let dataStore = WKWebsiteDataStore.default()
    private var hiddenWebView: WKWebView?
    private var loginWindow: NSWindow?
    private var loginWindowController: NSWindowController?

    private override init() { super.init() }

    // MARK: - Login

    /// Abre uma janela de verdade com o login do Cursor. A pessoa loga normalmente ali; ao fechar
    /// a janela (login concluído ou não), `onClose` roda pra quem chamou tentar ler a cota.
    func presentLogin(onClose: @escaping @Sendable () -> Void) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 480, height: 640), configuration: config)
        webView.load(URLRequest(url: URL(string: "https://cursor.com/dashboard")!))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Entrar no Cursor"
        window.contentView = webView
        window.center()

        let controller = NSWindowController(window: window)
        self.loginWindow = window
        self.loginWindowController = controller

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loginWindow = nil
                self?.loginWindowController = nil
                onClose()
            }
        }

        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Leitura

    /// Carrega o dashboard num WKWebView escondido e procura "N% used" no texto renderizado.
    /// `nil` quando não achou (sessão expirada, redirecionou pro login, ou o texto mudou de
    /// formato) — quem chama trata isso como "sem leitura desta vez", nunca inventa um número.
    func fetchUsagePercent(completion: @escaping @Sendable (Double?) -> Void) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore

        let webView = WKWebView(frame: .zero, configuration: config)
        self.hiddenWebView = webView // mantém vivo até o callback — sem isso é desalocado no meio do load

        let delegate = LoadDelegate { [weak self] webView in
            webView.evaluateJavaScript(Self.scrapeScript) { result, _ in
                self?.hiddenWebView = nil
                let percent = (result as? String).flatMap(Double.init)
                completion(percent)
            }
        }
        webView.navigationDelegate = delegate
        Self.retainedDelegate = delegate // mesmo motivo: precisa sobreviver até o callback

        webView.load(URLRequest(url: URL(string: "https://cursor.com/dashboard")!))

        // Teto de segurança: página que nunca termina de carregar (offline, bloqueio) não pode
        // deixar o refresh pendurado pra sempre.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard self?.hiddenWebView === webView else { return }
            self?.hiddenWebView = nil
            completion(nil)
        }
    }

    private static var retainedDelegate: LoadDelegate?

    /// Regex simples em cima do texto visível da página — não depende de classe CSS nem de
    /// estrutura de componente, que mudam a cada deploy. Só o padrão "número seguido de % used"
    /// (em inglês, como a UI do Cursor mostra hoje) precisa continuar existindo.
    private static let scrapeScript = """
    (function() {
        const text = document.body ? document.body.innerText : '';
        const match = text.match(/(\\d+(?:\\.\\d+)?)\\s*%\\s*used/i);
        return match ? match[1] : null;
    })();
    """

    private final class LoadDelegate: NSObject, WKNavigationDelegate {
        let onFinish: (WKWebView) -> Void
        init(onFinish: @escaping (WKWebView) -> Void) { self.onFinish = onFinish }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // A UI hidrata via JS depois do `didFinish` do documento — sem essa folga, o texto
            // ainda não existe no DOM e a leitura vem vazia com a página logada e certa.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.onFinish(webView)
            }
        }
    }
}
