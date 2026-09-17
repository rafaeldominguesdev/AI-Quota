import Cocoa

@main
struct AIQuotaApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // .accessory: sem ícone no Dock, sem menu na barra de aplicativos — só o status item.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
