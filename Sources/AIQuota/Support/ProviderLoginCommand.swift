import AppKit

/// O comando que faz login DE VERDADE em cada CLI — abrir a página de conta no navegador não
/// autentica a CLI (são sessões separadas). "Conectar" precisa rodar o comando de login da
/// própria CLI, que é o que grava a credencial que o app depois lê do disco.
///
/// Cursor entrou na lista depois de `CursorAccountReader` existir: `cursor-agent login` não
/// alimenta o banco de uso do editor (isso continua sem relação nenhuma), mas agora
/// `cursor-agent about --format json` lê e-mail + plano da mesma sessão — o suficiente pra
/// aparecer como "CONECTADO" de verdade depois do login, mesmo sem barra de consumo.
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
            : providerId.hasPrefix("codex") ? "Codex"
            : providerId == "cursor" ? "Cursor" : "Antigravity"

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
