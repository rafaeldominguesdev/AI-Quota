import Cocoa
import SwiftUI
import AIQuotaCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let store = QuotaStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        statusItem = item

        popover = makePopover()

        store.onOverviewUpdated = { [weak self] overview in
            self?.updateStatusItem(with: overview)
        }
        updateStatusItem(with: nil)
        store.startAutoRefresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stopAutoRefresh()
    }

    // MARK: - Popover

    private func makePopover() -> NSPopover {
        let hostingController = NSHostingController(rootView: PopoverRootView(store: store))
        // O SwiftUI dita a altura; o popover acompanha em vez de ter tamanho fixo.
        hostingController.sizingOptions = [.preferredContentSize]

        // Fundo preto de verdade: sem isto o macOS pinta o material claro do popover por baixo
        // da view SwiftUI e as bordas ficam cinzentas.
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.black.cgColor

        let popover = NSPopover()
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = hostingController
        return popover
    }

    /// O popover desenha a moldura e a setinha num `NSVisualEffectView` próprio, fora da nossa
    /// view SwiftUI. Sem mexer nele, sobra um halo translúcido claro em volta do painel preto.
    private func forceOpaqueBackground(on popover: NSPopover) {
        guard let frameView = popover.contentViewController?.view.superview else { return }
        frameView.wantsLayer = true
        frameView.layer?.backgroundColor = NSColor.black.cgColor
        for case let effectView as NSVisualEffectView in frameView.subviews + [frameView] {
            effectView.material = .hudWindow
            effectView.state = .inactive
            effectView.appearance = NSAppearance(named: .darkAqua)
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Recalcula assim que o painel abre, para não mostrar dado velho de até 30s atrás.
            store.refreshNow()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            forceOpaqueBackground(on: popover)
            popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Barra de menu

    /// Redesenha o indicador do NSStatusItem: a logo da IA principal e a barrinha carregada.
    /// O percentual usado é o do limite OFICIAL quando o provedor reporta um (dado medido), e só
    /// então a nossa estimativa por custo.
    private func updateStatusItem(with overview: QuotaOverview?) {
        guard let button = statusItem?.button else { return }

        let presentation = overview?.primary.map {
            ProviderPresentation(snapshot: $0, isPrimary: true)
        }
        let glyph = ProviderGlyph.forProvider(id: presentation?.id ?? "")
        let percent = presentation?.percent
        let color = presentation?.level?.nsColor ?? Theme.NS.inkFaint

        button.image = MenuBarIndicator.image(
            glyph: glyph,
            fraction: percent.map { $0 / 100 },
            color: color
        )

        guard MenuBarIndicator.showsPercentTextInMenuBar, let percent else {
            button.attributedTitle = NSAttributedString(string: "")
            return
        }

        button.attributedTitle = NSAttributedString(
            string: " \(Int(percent.rounded()))%",
            attributes: [
                .foregroundColor: color,
                .font: Theme.nsMono(11, .medium),
                .kern: 0.4
            ]
        )
    }
}
