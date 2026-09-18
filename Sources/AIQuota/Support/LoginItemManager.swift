import ServiceManagement

/// Liga/desliga o AI Quota como item de login do macOS, via `SMAppService` (API oficial desde o
/// macOS 13 — nada de scripts de AppleScript nem LaunchAgents escritos à mão). Só funciona de
/// verdade quando o app está rodando de dentro de um `.app` empacotado e assinado (o que
/// `scripts/build-app.sh` já faz); rodando via `swift run` o registro tende a falhar
/// silenciosamente, e por isso toda chamada aqui é best-effort.
enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Tenta aplicar o novo estado e devolve se deu certo — a UI só marca o checkbox quando a
    /// chamada realmente funcionou, nunca de forma otimista.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }
}
