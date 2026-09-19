import AppKit

/// A página de uso/conta de cada IA na web, e a tecla que a abre a partir do painel.
///
/// O app lê tudo do disco e nunca precisa da web para funcionar — isto é só um atalho para quando
/// o número do painel levanta a pergunta seguinte ("quanto sobrou mesmo?", "qual meu plano?"), que
/// só o site de cada IA responde.
///
/// As teclas são as iniciais do provedor, com duas exceções onde a inicial já estava tomada:
/// Codex vira **X** (o "C" é do Claude) e Cursor vira **U** (a segunda letra). Sem modificador:
/// o painel não tem campo de texto, então uma letra solta não conflita com nada.
enum ProviderWebConsole {
    struct Entry {
        let key: Character
        let url: URL
    }

    /// Chaveado pela FAMÍLIA do provedor (`claude-code`, `codex`...), não pelo id da conta: duas
    /// contas do Claude compartilham a mesma página e a mesma tecla.
    private static let entries: [String: Entry] = [
        "claude-code": Entry(key: "c", url: URL(string: "https://claude.ai/settings/usage")!),
        "codex": Entry(key: "x", url: URL(string: "https://chatgpt.com/#settings")!),
        "antigravity": Entry(key: "a", url: URL(string: "https://antigravity.google")!),
        "cursor": Entry(key: "u", url: URL(string: "https://cursor.com/dashboard")!),
        "grok": Entry(key: "k", url: URL(string: "https://grok.com")!)
    ]

    /// Mesma normalização de `ProviderGrouping`: "claude-code-work" e "claude-code" são a mesma
    /// família, logo a mesma tecla.
    static func entry(forProviderId id: String) -> Entry? {
        if id.hasPrefix("claude") { return entries["claude-code"] }
        if id.hasPrefix("codex") { return entries["codex"] }
        return entries[id]
    }

    /// O selo que a UI desenha ("C", "X"...). `nil` para provedor customizado, que não tem página
    /// conhecida — nesses casos não inventamos tecla nem endereço.
    static func keyLabel(forProviderId id: String) -> String? {
        entry(forProviderId: id).map { String($0.key).uppercased() }
    }

    static func open(providerId: String) {
        guard let entry = entry(forProviderId: providerId) else { return }
        NSWorkspace.shared.open(entry.url)
    }
}
