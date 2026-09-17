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

    /// Redesenha o medidor e o percentual do NSStatusItem a partir do overview mais recente.
    /// O percentual mostrado é o do provedor principal, preferindo o limite OFICIAL quando o
    /// provedor reporta um (dado medido) em vez da nossa estimativa por custo.
    private func updateStatusItem(with overview: QuotaOverview?) {
        guard let button = statusItem?.button else { return }

        let presentation = overview?.primary.map {
            ProviderPresentation(snapshot: $0, isPrimary: true)
        }

        guard let presentation, let percent = presentation.percent, let level = presentation.level else {
            button.image = MenuBarGauge.image(fraction: nil, color: Theme.NS.inkFaint)
            button.attributedTitle = NSAttributedString(
                string: " —",
                attributes: [
                    .foregroundColor: Theme.NS.inkFaint,
                    .font: Theme.nsMono(11, .medium)
                ]
            )
            return
        }

        button.image = MenuBarGauge.image(fraction: percent / 100, color: level.nsColor)
        button.attributedTitle = NSAttributedString(
            string: " \(Int(percent.rounded()))%",
            attributes: [
                .foregroundColor: level.nsColor,
                .font: Theme.nsMono(11, .medium),
                .kern: 0.4
            ]
        )
    }
}
