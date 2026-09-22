import AppKit

/// O comando que faz login DE VERDADE em cada CLI — abrir a página de conta no navegador não
/// autentica a CLI (são sessões separadas). "Conectar" precisa rodar o comando de login da
/// própria CLI, que é o que grava a credencial que o app depois lê do disco.
///
/// Cursor fica de fora de propósito: `cursor-agent login` autentica a CLI, mas o que este app lê
/// (`ai-code-tracking.db`) é um registro de código gerado no EDITOR, sem nenhuma ligação com essa
/// sessão — logar não muda nada aqui. Pra Cursor, a página web (com o % de verdade da conta) é a
/// única fonte que faz sentido, então ele cai no fallback de `ProviderWebConsole`.
enum ProviderLoginCommand {
    private static let commands: [String: String] = [
        "claude-code": "claude auth login",
        "codex": "codex login",
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

    /// Abre um `.command` temporário via Finder em vez de mandar AppleScript pro Terminal.
    ///
    /// A primeira versão usava `osascript … tell application "Terminal"`, que pede permissão de
    /// Automação (Apple Events) ao macOS. Em apps sem ícone no Dock (`LSUIElement`, como este) essa
    /// caixa de permissão às vezes nasce atrás de tudo — o app parece travado porque, na prática,
    /// está esperando uma resposta a uma caixa que ninguém está vendo. Um `.command` aberto pelo
    /// Finder não pede NENHUMA permissão: é o mesmo mecanismo de dar duplo-clique num script.
    static func openInTerminal(providerId: String) {
        guard let command = command(forProviderId: providerId) else { return }
        let displayName = providerId.hasPrefix("claude") ? "Claude Code"
            : providerId.hasPrefix("codex") ? "Codex" : "Antigravity"

        let script = """
        #!/bin/zsh
        echo "Conectando \(displayName)…"
        echo
        \(command)
        echo
        read "?Pronto. Pressione Enter para fechar esta janela."
        """

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-quota-login-\(providerId)-\(UUID().uuidString.prefix(8)).command")

        do {
            try script.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            NSWorkspace.shared.open(url)
        } catch {
            // Sem plano B: se não deu para escrever no diretório temporário do próprio usuário,
            // não há nada de útil a fazer além de deixar o botão sem efeito.
        }
    }
}
