import AppKit
import SwiftUI

/// A janela de Ajustes, fora do popover.
///
/// Por que uma janela e não mais uma tela dentro do popover: o popover tem 292pt de largura e
/// fecha ao perder o foco — serve pra consultar, não pra configurar. A janela tem a largura do
/// print (680) e fica aberta enquanto o usuário mexe.
///
/// O app é `.accessory` (não aparece no Dock nem no Cmd+Tab), então uma janela sua não ganha foco
/// sozinha: `activate(ignoringOtherApps:)` é o que traz ela pra frente. Sem isso ela abre atrás
/// da janela de quem estava na frente.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(store: QuotaStore) {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: SettingsWindowView(store: store))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Ajustes"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.backgroundColor = Theme.NS.bg
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false

        // Fixa de propósito, a pedido do usuário: nem arrastável nem redimensionável, e acima das
        // outras janelas. O app é `.accessory` — sem Dock e sem Cmd+Tab, uma janela que fosse para
        // trás de outra não teria como ser trazida de volta a não ser reabrindo pelo menu.
        window.isMovable = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.center()

        // Sem isso a janela some da memória do controlador quando o usuário fecha no X, e o
        // próximo "Ajustes" abriria uma segunda janela por cima da primeira.
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.window = nil }
        }

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.performClose(nil)
    }
}
