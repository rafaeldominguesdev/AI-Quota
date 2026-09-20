import Foundation

/// De onde a cota de um provedor por chave é lida — e, quando não há de onde, dizer isso.
///
/// Inventar um número aqui seria pior do que não ter número: o app existe para responder
/// "quanto me resta", e um `0%` fabricado responde errado com cara de certo.
public enum APIUsageEndpoint: Sendable, Equatable {
    /// `GET /api/v1/key` + `/api/v1/credits` — devolve limite, gasto e se é free tier.
    case openRouter
    /// `GET /user/balance` — saldo restante em moeda.
    case deepSeekBalance
    /// `GET /v1/users/me/balance` — saldo restante em moeda.
    case moonshotBalance
    /// Sem endpoint de cota conhecido: a chave é VALIDADA contra `/models` e o provedor
    /// aparece como conectado, sem barra de consumo. Honesto em vez de decorativo.
    case validateOnly(path: String)
}

/// Um provedor que entra por CHAVE de API, não por CLI logada.
///
/// A lista espelha a do Hyperion (`KEY_PROVIDERS` em `App.tsx`): é o mesmo conjunto de
/// provedores, para que o que você conecta lá apareça aqui.
public struct APIProviderDef: Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    /// Onde a pessoa pega a chave — abre no navegador pelo botão da UI.
    public let keysURL: String
    public let baseURL: String
    public let usage: APIUsageEndpoint
    /// Prefixo esperado da chave, quando o provedor tem um. Serve para avisar ANTES de gastar
    /// uma chamada de rede que a pessoa colou a chave errada.
    public let keyPrefix: String?

    public init(
        id: String,
        displayName: String,
        keysURL: String,
        baseURL: String,
        usage: APIUsageEndpoint,
        keyPrefix: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.keysURL = keysURL
        self.baseURL = baseURL
        self.usage = usage
        self.keyPrefix = keyPrefix
    }
}

public enum APIProviderCatalog {
    public static let all: [APIProviderDef] = [
        APIProviderDef(
            id: "openrouter",
            displayName: "OpenRouter",
            keysURL: "https://openrouter.ai/keys",
            baseURL: "https://openrouter.ai/api/v1",
            usage: .openRouter,
            keyPrefix: "sk-or-"
        ),
        APIProviderDef(
            id: "deepseek",
            displayName: "DeepSeek",
            keysURL: "https://platform.deepseek.com/api_keys",
            baseURL: "https://api.deepseek.com",
            usage: .deepSeekBalance,
            keyPrefix: "sk-"
        ),
        APIProviderDef(
            id: "moonshot",
            displayName: "Moonshot / Kimi",
            keysURL: "https://platform.moonshot.cn/console/api-keys",
            baseURL: "https://api.moonshot.cn/v1",
            usage: .moonshotBalance,
            keyPrefix: "sk-"
        ),
        APIProviderDef(
            id: "fireworks",
            displayName: "Fireworks",
            keysURL: "https://fireworks.ai/api-keys",
            baseURL: "https://api.fireworks.ai/inference/v1",
            // A Fireworks não publica endpoint de saldo na API de inferência: a chave é
            // validada e o provedor entra sem barra, em vez de ganhar um número inventado.
            usage: .validateOnly(path: "/models")
        ),
        APIProviderDef(
            id: "zai",
            displayName: "GLM (Z.ai)",
            keysURL: "https://open.bigmodel.cn/usercenter/apikeys",
            baseURL: "https://open.bigmodel.cn/api/paas/v4",
            usage: .validateOnly(path: "/models")
        )
    ]

    public static func find(_ id: String) -> APIProviderDef? {
        all.first { $0.id == id }
    }
}
