import Foundation

/// Cota do Antigravity.
///
/// **Fonte primária: cota REAL**, obtida rodando o CLI do usuário (`agy --print "/usage"`) — ver
/// `AntigravityUsageReader`. Devolve o percentual usado por grupo de modelos (Gemini; Claude/GPT)
/// e quando cada janela semanal reseta, igual às barras oficiais do Claude e do Codex.
///
/// **Fallback: contagem de sessões.** Se o `agy` não estiver instalado, a máquina estiver offline
/// ou a conta deslogada, caímos para contar os arquivos de log de sessão
/// (`log/cli-AAAAMMDD_HHMMSS.log`) — pelo menos "usei / não usei", nunca um painel vazio. Não é o
/// `history.jsonl` de propósito: ele só guarda o que foi digitado e congela (aqui parou semanas
/// antes dos logs de sessão).
public struct AntigravityProvider: QuotaProvider {
    public let id = "antigravity"
    public let displayName = "Antigravity"
    public let kind: ProviderDataKind = .countOnly

    private let home: URL

    public init(
        home: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini/antigravity-cli")
    ) {
        self.home = home
    }

    public var sourcePath: String { home.path }

    public var isInstalled: Bool {
        FileManager.default.fileExists(atPath: home.path)
    }

    public func snapshot(config: QuotaConfig) throws -> ProviderSnapshot {
        guard isInstalled else {
            return .unavailable(
                providerId: id, displayName: displayName, isInstalled: false,
                note: "Diretório \(sourcePath) não encontrado"
            )
        }

        let reader = AntigravitySessionReader(home: home)
        let email = reader.readAccountEmail()

        // Cota real primeiro. Quando o `agy` responde, o Antigravity vira um provedor de cota
        // completo, com uma barra por grupo de modelos — sem tokens (o Antigravity não expõe),
        // mas com o percentual e o reset oficiais.
        if let officialLimits = AntigravityUsageReader.read(), !officialLimits.isEmpty {
            return ProviderSnapshot(
                providerId: id, displayName: displayName, kind: .countOnly, isInstalled: true,
                windowStart: nil, windowEnd: nil, isActive: true,
                totalTokens: 0, totalCost: nil, eventCount: 0, byModel: [],
                officialLimits: officialLimits,
                note: nil, hourlyUsage: [], planLabel: nil, accountEmail: email
            )
        }

        // Fallback: contagem de sessões do CLI.
        let events = reader.readSessions()
        guard let last = UsageWindowBuilder.windows(for: events).last else {
            // Sem sessão, mas a conta logada continua sendo informação boa — por isso não usamos
            // o `.unavailable`, que descartaria o e-mail.
            return ProviderSnapshot(
                providerId: id, displayName: displayName, kind: .countOnly, isInstalled: true,
                windowStart: nil, windowEnd: nil, isActive: false,
                totalTokens: 0, totalCost: nil, eventCount: 0, byModel: [],
                note: "Nenhuma sessão registrada em \(sourcePath)/log",
                accountEmail: email
            )
        }

        let count = last.events.count
        return ProviderSnapshot(
            providerId: id,
            displayName: displayName,
            kind: .countOnly,
            isInstalled: true,
            windowStart: last.window.start,
            windowEnd: last.window.end,
            isActive: last.window.isActive(),
            totalTokens: 0,
            totalCost: nil,
            eventCount: count,
            byModel: [
                ProviderModelUsage(
                    model: "desconhecido", totalTokens: 0, eventCount: count,
                    cost: nil, isEstimatedPricing: false
                )
            ],
            note: "Sem dado de token nem de cota: o Antigravity só consulta a cota no servidor, "
                + "nunca grava o número em disco. Aqui é a contagem de sessões do CLI.",
            hourlyUsage: UsageWindowBuilder.hourlyBuckets(for: last.events, window: last.window) { _ in 1 },
            accountEmail: email
        )
    }
}
