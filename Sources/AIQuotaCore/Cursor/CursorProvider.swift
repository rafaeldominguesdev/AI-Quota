import Foundation

/// Wraps the existing `CursorUsageReader` behind the `QuotaProvider` protocol. Cursor's database
/// has no token counts (confirmed in the original data-source survey) — only model + timestamp
/// per generated hash — so this is always `.countOnly`.
public struct CursorProvider: QuotaProvider {
    public let id = "cursor"
    public let displayName = "Cursor"
    public let kind: ProviderDataKind = .countOnly

    private let reader: CursorUsageReader
    private let accountReader: CursorAccountReader

    public init(reader: CursorUsageReader = CursorUsageReader(), accountReader: CursorAccountReader = CursorAccountReader()) {
        self.reader = reader
        self.accountReader = accountReader
    }

    public var sourcePath: String { reader.databasePath }

    public var isInstalled: Bool {
        FileManager.default.fileExists(atPath: sourcePath)
    }

    public func snapshot(config: QuotaConfig) throws -> ProviderSnapshot {
        // A identidade vem do próprio `cursor-agent` (login de CLI), não do banco de uso do
        // editor — as duas coisas são independentes. Sem isso, logar pela CLI nunca mudava nada
        // aqui, mesmo com a sessão válida.
        let account = accountReader.read()

        // Raspado da web pelo `CursorWebSession` (target do app, WebKit) — nenhuma API do Cursor
        // publica esse número, então é o único jeito honesto de ter uma barra de %. Some sozinho
        // depois de `CursorWebUsageCache.maxAge` sem leitura nova, em vez de mostrar algo velho
        // como se fosse de agora.
        let webUsage = CursorWebUsageCache.load()
        let officialLimits: [OfficialLimitInfo] = webUsage.map {
            [OfficialLimitInfo(label: "Cota (site)", usedPercent: $0.percentUsed, resetsAt: nil)]
        } ?? []

        let records = reader.readUsageRecords()

        // Sem a % real do site ainda (nunca logou, ou a sessão expirou) — dá pra ter uma noção
        // aproximada sem depender de login nenhum: conta quantos usos aconteceram desde o início
        // do mês corrente e compara com `cursorMonthlyEventCeiling`. Some sozinho assim que a
        // leitura real da web existir, para não mostrar dois números conflitantes.
        let estimatedLimits: [OfficialLimitInfo] = webUsage == nil
            ? Self.monthlyEstimate(records: records, config: config)
            : []

        guard isInstalled else {
            return .unavailable(
                providerId: id, displayName: displayName, isInstalled: false,
                note: "Banco \(sourcePath) não encontrado", officialLimits: officialLimits,
                estimatedLimits: estimatedLimits,
                planLabel: account?.planLabel, accountEmail: account?.email
            )
        }

        guard let last = UsageWindowBuilder.windows(for: records).last else {
            return .unavailable(
                providerId: id, displayName: displayName, kind: .countOnly, isInstalled: true,
                note: account != nil
                    ? "Logado, mas sem uso registrado em \(sourcePath) — o Cursor só grava ao gerar código no editor."
                    : "Nenhum uso registrado em \(sourcePath)",
                officialLimits: officialLimits,
                estimatedLimits: estimatedLimits,
                planLabel: account?.planLabel, accountEmail: account?.email
            )
        }

        let byModel = Dictionary(grouping: last.events, by: { $0.model })
            .map { model, records in
                ProviderModelUsage(model: model, totalTokens: 0, eventCount: records.count, cost: nil, isEstimatedPricing: false)
            }
            .sorted { $0.eventCount > $1.eventCount }

        let hourlyUsage = UsageWindowBuilder.hourlyBuckets(for: last.events, window: last.window) { _ in 1 }

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
            eventCount: last.events.count,
            byModel: byModel,
            officialLimits: officialLimits,
            estimatedLimits: estimatedLimits,
            note: "Sem dado de token: o Cursor só registra quantas vezes cada modelo foi usado.",
            hourlyUsage: hourlyUsage,
            planLabel: account?.planLabel,
            accountEmail: account?.email
        )
    }

    /// Usos desde a meia-noite do dia 1 do mês corrente contra `cursorMonthlyEventCeiling`. Uma
    /// aproximação deliberadamente simples (mês civil, não ciclo real de cobrança, que o Cursor
    /// não expõe em lugar nenhum local) — melhor que nada enquanto a % real da web não existe.
    static func monthlyEstimate(
        records: [CursorUsageRecord], config: QuotaConfig, now: Date = Date(), calendar: Calendar = .current
    ) -> [OfficialLimitInfo] {
        guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start,
              let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
        }
        let count = records.filter { $0.timestamp >= monthStart }.count
        guard config.cursorMonthlyEventCeiling > 0 else { return [] }
        let percent = Double(count) / config.cursorMonthlyEventCeiling * 100
        return [OfficialLimitInfo(label: "Mês (estim.)", usedPercent: percent, resetsAt: nextMonthStart)]
    }
}
