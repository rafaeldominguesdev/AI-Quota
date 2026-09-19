import Foundation

/// Um provedor pode aparecer mais de uma vez na lista — uma entrada por conta extra que
/// `MultiAccountDiscovery` encontrar (`claude-code`, `claude-code-work`...). Agrupamos por
/// família aqui para desenhar UM cabeçalho (logo + nome) por provedor, com uma conta abaixo do
/// outra, em vez de repetir logo e nome pra cada conta.
struct ProviderGroup: Identifiable {
    let id: String
    let displayName: String
    let accounts: [ProviderPresentation]

    /// A primeira conta do grupo decide o glifo/estado geral (cor do indicador, se está apagado).
    var primary: ProviderPresentation { accounts[0] }
}

enum ProviderGrouping {
    /// "claude-code-work" → "claude-code", "codex-personal" → "codex", qualquer outro id fica
    /// como está (antigravity/grok/cursor/custom não têm múltiplas contas hoje).
    private static func family(of id: String) -> String {
        if id.hasPrefix("claude") { return "claude-code" }
        if id.hasPrefix("codex") { return "codex" }
        return id
    }

    /// Nome do grupo: o nome de exibição da conta padrão, sem o sufixo "(Work)" / "(Pessoal)"
    /// que só faz sentido por conta — o cabeçalho do grupo é o provedor, não a conta. O Codex
    /// ganha "(GPT)" fixo, do jeito do print de referência (deixa claro de qual empresa é,
    /// já que "Codex" sozinho não entrega isso tão bem quanto "Claude"/"Cursor"/"Grok").
    private static func groupDisplayName(family: String, accounts: [ProviderPresentation]) -> String {
        if family == "codex" { return "Codex (GPT)" }
        let name = accounts[0].displayName
        guard let parenIndex = name.firstIndex(of: "(") else { return name }
        return String(name[name.startIndex..<parenIndex]).trimmingCharacters(in: .whitespaces)
    }

    /// Agrupa preservando a ordem de chegada (que já vem de `providerRows`/`connectedProviders`,
    /// priorizada por quem tem percentual) — só junta linhas adjacentes-ou-não da mesma família.
    static func group(_ rows: [ProviderPresentation]) -> [ProviderGroup] {
        var order: [String] = []
        var buckets: [String: [ProviderPresentation]] = [:]
        for row in rows {
            let key = family(of: row.id)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(row)
        }
        return order.map { key in
            let accounts = buckets[key]!
            return ProviderGroup(id: key, displayName: groupDisplayName(family: key, accounts: accounts), accounts: accounts)
        }
    }
}
