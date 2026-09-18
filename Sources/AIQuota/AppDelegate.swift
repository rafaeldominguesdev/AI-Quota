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

        store.onOverviewUpdated = { [weak self] _ in
            self?.updateStatusItem()
        }
        updateStatusItem()
        store.startAutoRefresh()
        installTemporaryVisualCheckHook()
    }

    // BLOCO TEMPORARIO DE VERIFICACAO VISUAL - REMOVER ANTES DO COMMIT
    private func installTemporaryVisualCheckHook() {
        guard ProcessInfo.processInfo.environment["AIQUOTA_SELFTEST"] == "1" else { return }
        Task { @MainActor in
            for _ in 0..<120 where self.store.overview == nil {
                try? await Task.sleep(for: .seconds(1))
            }
            try? await Task.sleep(for: .seconds(1))
            self.togglePopover(nil)
            try? await Task.sleep(for: .seconds(2))

            let dir = ProcessInfo.processInfo.environment["AIQUOTA_SELFTEST_OUT"] ?? "/tmp"

            @MainActor func shoot<V: View>(_ view: V, _ name: String) {
                let renderer = ImageRenderer(
                    content: view.background(Theme.bg).environment(\.colorScheme, .dark)
                )
                renderer.scale = 3
                if let image = renderer.nsImage,
                   let tiff = image.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: dir + "/" + name))
                }
            }

            shoot(PopoverRootView(store: self.store), "painel.png")
            shoot(ProvidersScreenView(store: self.store, onBack: {}).frame(width: Theme.Metric.panelWidth), "provedores.png")

            // A imagem da barra de menu na escala REAL da Retina (2x) e com zoom sem
            // interpolacao, para julgar nitidez da logo a 12pt.
            if let image = self.statusItem?.button?.image {
                let points = image.size
                for (zoom, name) in [(1.0, "barra-retina-2x.png"), (6.0, "barra-retina-zoom.png")] {
                    let pixels = NSSize(width: points.width * 2, height: points.height * 2)
                    guard let rep = NSBitmapImageRep(
                        bitmapDataPlanes: nil,
                        pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
                    ) else { continue }
                    rep.size = points
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                    Theme.NS.bg.setFill()
                    NSRect(origin: .zero, size: points).fill()
                    image.draw(in: NSRect(origin: .zero, size: points))
                    NSGraphicsContext.restoreGraphicsState()

                    let target = NSSize(width: pixels.width * zoom, height: pixels.height * zoom)
                    let canvas = NSImage(size: target)
                    canvas.lockFocus()
                    NSGraphicsContext.current?.imageInterpolation = .none
                    rep.draw(in: NSRect(origin: .zero, size: target))
                    canvas.unlockFocus()
                    if let tiff = canvas.tiffRepresentation,
                       let out = NSBitmapImageRep(data: tiff),
                       let png = out.representation(using: .png, properties: [:]) {
                        try? png.write(to: URL(fileURLWithPath: dir + "/" + name))
                    }
                }
            }

            // Quais logos resolveram de verdade NESTE processo — é o que prova que o
            // Bundle.module funciona dentro do .app empacotado.
            let ids = ["claude-code", "codex", "grok", "gemini", "cursor", "deepseek"]
            let resolved = ids.map { id -> String in
                if let image = ProviderLogo.image(for: id) {
                    return "\(id)=\(Int(image.size.width))x\(Int(image.size.height))"
                }
                return "\(id)=glifo"
            }
            let size = self.popover?.contentSize ?? .zero
            let report = """
            executavel=\(Bundle.main.bundlePath)
            popover_aberto=\(self.popover?.isShown ?? false)
            painel=\(size.width)x\(size.height)pt
            logos=\(resolved.joined(separator: " "))
            barra_menu=\(self.statusItem?.button?.image?.size.width ?? 0)x\(self.statusItem?.button?.image?.size.height ?? 0)pt
            """
            try? report.write(to: URL(fileURLWithPath: dir + "/report.txt"), atomically: true, encoding: .utf8)
        }
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

    /// Redesenha o indicador do NSStatusItem: uma logo por IA conectada (Claude, Codex etc.),
    /// cada uma seguida de uma barrinha + tempo até resetar por janela de cota que ela reporta,
    /// e um traço fino separando uma IA da próxima. O percentual de cada barra é o do limite
    /// OFICIAL quando o provedor reporta um (dado medido), e só então a nossa estimativa por
    /// custo.
    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }

        // Sem rótulo de tempo aqui de propósito: a barra de menu mostra só o gasto (a
        // barrinha); o tempo até resetar fica pro painel, que abre com um clique.
        let groups = store.connectedProviders.map { presentation -> MenuBarIndicator.Group in
            let windows = presentation.windows.map { window in
                MenuBarIndicator.Window(
                    fraction: window.percent / 100,
                    color: window.level.nsColor
                )
            }
            return MenuBarIndicator.Group(providerId: presentation.id, windows: windows)
        }
        button.image = MenuBarIndicator.image(groups: groups)
        button.attributedTitle = NSAttributedString(string: "")
    }
}
