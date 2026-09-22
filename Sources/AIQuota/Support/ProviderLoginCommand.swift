import AppKit

/// O comando que faz login DE VERDADE em cada CLI — abrir a página de conta no navegador não
/// autentica a CLI (são sessões separadas). "Conectar" precisa rodar o comando de login da
/// própria CLI, que é o que grava a credencial que o app depois lê do disco.
enum ProviderLoginCommand {
    private static let commands: [String: String] = [
        "claude-code": "claude auth login",
        "codex": "codex login",
        "cursor": "cursor-agent login",
        // Sem subcomando de login: `agy` dispara o fluxo de autenticação sozinho na primeira
        // vez que abre, e não faz nada de mal se já estiver logado.
        "antigravity": "agy"
    ]

    /// Mesma normalização de `ProviderWebConsole`: variações de conta (`claude-code-work`) usam
    /// o comando da família.
    static func command(forProviderId id: String) -> String? {
        if id.hasPrefix("claude") { return commands["claude-code"] }
        if id.hasPrefix("codex") { return commands["codex"] }
        return commands[id]
    }

    /// Abre o Terminal.app já rodando o comando — a pessoa faz o OAuth ali, e a próxima leitura
    /// automática do app (a cada 30s) já pega a conta nova, sem precisar voltar aqui.
    static func openInTerminal(providerId: String) {
        guard let command = command(forProviderId: providerId) else { return }
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        try? task.run()
    }
}
