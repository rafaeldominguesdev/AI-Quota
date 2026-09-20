import Foundation

/// Um provedor por CHAVE: a cota não está num log no disco, está na API dele.
///
/// A chamada de rede é SÍNCRONA de propósito. `ProviderRegistry.buildOverview()` já roda dentro
/// de uma `Task.detached` (ver `QuotaStore.refreshNow`), então bloquear aqui não trava a
/// interface — e deixa o protocolo `QuotaProvider` como está, sem contaminar os provedores de
/// log com async que eles não precisam.
public struct APIQuotaProvider: QuotaProvider {
    private let def: APIProviderDef
    private let account: APIAccount
    private let session: URLSession
    private let timeout: TimeInterval

    public init(def: APIProviderDef, account: APIAccount, timeout: TimeInterval = 8) {
        self.def = def
        self.account = account
        self.timeout = timeout
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = timeout
        cfg.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: cfg)
    }

    /// `openrouter:<id da conta>` — o id precisa ser único por CONTA, não por provedor, senão
    /// duas chaves do mesmo provedor colidiriam e uma sumiria do painel.
    public var id: String { "\(def.id):\(account.id)" }

    public var displayName: String {
        APIAccountStore.accounts(for: def.id).count > 1
            ? "\(def.displayName) (\(account.label))"
            : def.displayName
    }

    /// Provedor por chave não se "instala": ter chave cadastrada é o equivalente.
    public var isInstalled: Bool { !account.key.isEmpty }

    public var sourcePath: String { def.baseURL }

    public var kind: ProviderDataKind {
        // Nenhuma dessas APIs devolve tokens de entrada/saída do período — devolvem saldo e
        // limite. `countOnly` seria mentira (não é contagem de eventos), então o que vale é o
        // que a barra mostra: limite oficial, sem token nenhum.
        switch def.usage {
        case .validateOnly: return .unavailable
        default: return .tokensOnly
        }
    }

    public func snapshot(config: QuotaConfig) throws -> ProviderSnapshot {
        switch def.usage {
        case .openRouter: return try openRouterSnapshot()
        case .deepSeekBalance:
            return try balanceSnapshot(path: "/user/balance", parse: Self.parseDeepSeekBalance)
        case .moonshotBalance:
            return try balanceSnapshot(path: "/users/me/balance", parse: Self.parseMoonshotBalance)
        case .validateOnly(let path): return try validateSnapshot(path: path)
        }
    }

    // MARK: - Rede

    private func get(_ url: URL) throws -> [String: Any] {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.setValue("Bearer \(account.key)", forHTTPHeaderField: "Authorization")

        // A caixa existe porque a closure do `dataTask` roda noutra thread: capturar um `var`
        // local direto é o que o compilador acusa em `SendableClosureCaptures`. O acesso é
        // serializado pelo semáforo (escreve antes do signal, lê depois do wait).
        final class Box: @unchecked Sendable {
            var value: Result<[String: Any], Error> = .failure(APIQuotaError.noResponse)
        }
        let box = Box()
        let sem = DispatchSemaphore(value: 0)
        session.dataTask(with: req) { data, resp, err in
            defer { sem.signal() }
            if let err { box.value = .failure(err); return }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else {
                box.value = .failure(APIQuotaError.http(code)); return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { box.value = .failure(APIQuotaError.badPayload); return }
            box.value = .success(json)
        }.resume()
        _ = sem.wait(timeout: .now() + timeout + 2)
        return try box.value.get()
    }

    private func url(_ path: String) throws -> URL {
        guard let u = URL(string: def.baseURL + path) else { throw APIQuotaError.badPayload }
        return u
    }

    // MARK: - OpenRouter

    private func openRouterSnapshot() throws -> ProviderSnapshot {
        let key = try get(try url("/key"))
        let d = (key["data"] as? [String: Any]) ?? [:]

        let usage = (d["usage"] as? NSNumber)?.doubleValue ?? 0
        let limit = (d["limit"] as? NSNumber)?.doubleValue
        let isFree = (d["is_free_tier"] as? Bool) ?? false

        var limits: [OfficialLimitInfo] = []
        if let limit, limit > 0 {
            limits.append(
                OfficialLimitInfo(
                    label: "crédito da chave",
                    usedPercent: min(100, (usage / limit) * 100),
                    resetsAt: nil
                )
            )
        }

        // Conta sem crédito comprado cai no teto de requisições/dia dos modelos `:free`. Esse
        // teto a API não reporta, então ele vira NOTA, não barra: só o que veio do provedor
        // vira número.
        var nota: String?
        if isFree {
            nota = limits.isEmpty
                ? "Free tier, sem crédito comprado — só modelos :free, com teto diário"
                : "Free tier: modelos :free têm teto diário que a API não reporta"
        }

        return snapshot(cost: usage, limits: limits, note: nota)
    }

    // MARK: - Saldo em moeda

    private func balanceSnapshot(
        path: String,
        parse: ([String: Any]) -> (used: Double?, remaining: Double?)
    ) throws -> ProviderSnapshot {
        let json = try get(try url(path))
        let b = parse(json)

        var limits: [OfficialLimitInfo] = []
        if let remaining = b.remaining, let used = b.used, used + remaining > 0 {
            limits.append(
                OfficialLimitInfo(
                    label: "saldo",
                    usedPercent: min(100, used / (used + remaining) * 100),
                    resetsAt: nil
                )
            )
        }
        let nota = b.remaining.map { String(format: "Saldo restante: %.2f", $0) }
        return snapshot(cost: b.used, limits: limits, note: nota)
    }

    static func parseDeepSeekBalance(_ json: [String: Any]) -> (used: Double?, remaining: Double?) {
        guard let infos = json["balance_infos"] as? [[String: Any]], let first = infos.first
        else { return (nil, nil) }
        let total = Double(first["total_balance"] as? String ?? "") ?? nil
        return (nil, total)
    }

    static func parseMoonshotBalance(_ json: [String: Any]) -> (used: Double?, remaining: Double?) {
        guard let d = json["data"] as? [String: Any] else { return (nil, nil) }
        return (nil, (d["available_balance"] as? NSNumber)?.doubleValue)
    }

    // MARK: - Só validação

    private func validateSnapshot(path: String) throws -> ProviderSnapshot {
        _ = try get(try url(path))
        return snapshot(
            cost: nil,
            limits: [],
            note: "Conectado. Este provedor não publica endpoint de cota — sem barra de consumo."
        )
    }

    // MARK: -

    private func snapshot(cost: Double?, limits: [OfficialLimitInfo], note: String?) -> ProviderSnapshot {
        ProviderSnapshot(
            providerId: id,
            displayName: displayName,
            kind: kind,
            isInstalled: true,
            windowStart: nil,
            windowEnd: nil,
            // Provedor por chave não tem "sessão": não há janela de 5h para estar dentro.
            isActive: false,
            totalTokens: 0,
            totalCost: cost,
            eventCount: 0,
            byModel: [],
            officialLimits: limits,
            note: note,
            hourlyUsage: [],
            planLabel: nil,
            accountEmail: account.label
        )
    }
}

public enum APIQuotaError: LocalizedError, Equatable {
    case http(Int)
    case badPayload
    case noResponse

    public var errorDescription: String? {
        switch self {
        case .http(401), .http(403): return "chave recusada pelo provedor"
        case .http(let c): return "o provedor respondeu HTTP \(c)"
        case .badPayload: return "resposta em formato inesperado"
        case .noResponse: return "sem resposta do provedor"
        }
    }
}
