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

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.contentViewController = NSHostingController(rootView: PopoverContentView(store: store))
        self.popover = popover

        store.onSnapshotUpdated = { [weak self] snapshot in
            self?.updateStatusItem(with: snapshot)
        }
        updateStatusItem(with: nil)
        store.startAutoRefresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stopAutoRefresh()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Recalcula assim que o painel abre, para não mostrar dado velho de até 30s atrás.
            store.refreshNow()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Atualiza o ícone e o texto colorido do NSStatusItem a partir do snapshot mais recente.
    private func updateStatusItem(with snapshot: QuotaSnapshot?) {
        guard let button = statusItem?.button else { return }

        // Ícone SF Symbol como template: monocromático, se adapta sozinho ao tema da barra de
        // menu. A cor do ESTADO fica só no texto do percentual, nunca no ícone.
        if button.image == nil {
            let symbolName = "gauge.with.dots.needle.bottom.50percent"
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "AI Quota")
                ?? NSImage(systemSymbolName: "chart.pie.fill", accessibilityDescription: "AI Quota")
            image?.isTemplate = true
            button.image = image
        }

        let font = NSFont.menuBarFont(ofSize: 0)

        guard let snapshot, snapshot.isActive else {
            button.attributedTitle = NSAttributedString(
                string: " —",
                attributes: [.foregroundColor: StatusColor.neutralNSColor, .font: font]
            )
            return
        }

        let percentText = " \(Int(snapshot.usagePercent.rounded()))%"
        button.attributedTitle = NSAttributedString(
            string: percentText,
            attributes: [.foregroundColor: StatusColor.nsColor(for: snapshot.state), .font: font]
        )
    }
}
