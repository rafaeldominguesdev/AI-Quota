import Foundation

/// Wraps the existing (and already tested) `ClaudeCodeLogReader` / `FiveHourBlockBuilder` /
/// `CostCalculator` pipeline behind the `QuotaProvider` protocol. No behavior changes here —
/// this is purely an adapter so Claude Code shows up alongside the other providers.
public struct ClaudeCodeProvider: QuotaProvider {
    public let id: String
    public let displayName: String
    public let kind: ProviderDataKind = .fullTokens

    private let reader: ClaudeCodeLogReader
    private let accountReader: ClaudeAccountReader
    private let credentialsFile: URL
    /// Memória entre refreshes, usada só para detectar leitura defasada do endpoint na virada da
    /// janela (ver `reconciledWithLocalUsage`). Injetável para os testes não tocarem o disco.
    private let journal: UsageObservationJournal
    private let now: @Sendable () -> Date

    /// `id`/`displayName` têm outro valor só para uma segunda (terceira...) conta descoberta por
    /// `MultiAccountDiscovery` — a conta padrão continua "claude-code"/"Claude Code". Idem
    /// `credentialsFile`: a conta extra tem o seu próprio `.credentials.json` dentro da própria
    /// pasta `.claude-<algo>`, separado do da conta padrão.
    public init(
        reader: ClaudeCodeLogReader = ClaudeCodeLogReader(),
        accountReader: ClaudeAccountReader = ClaudeAccountReader(),
        credentialsFile: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json"),
        id: String = "claude-code",
        displayName: String = "Claude Code",
        journal: UsageObservationJournal = .shared,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.reader = reader
        self.accountReader = accountReader
        self.credentialsFile = credentialsFile
        self.journal = journal
        self.now = now
        self.id = id
        self.displayName = displayName
    }

    /// "claude_pro" → "Pro", "claude_max" → "Max"... o prefixo "claude_" nunca aparece na UI.
    private static func planLabel(organizationType: String?) -> String? {
        guard let organizationType, organizationType.hasPrefix("claude_") else { return organizationType }
        return organizationType
            .dropFirst("claude_".count)
            .capitalized
    }

    /// Decide, **sem relógio**, se um percentual oficial ainda descreve a janela anterior.
    ///
    /// O problema: na virada, o endpoint (e o cache do CLI) devolvem o `resets_at` NOVO junto com
    /// o percentual VELHO — o painel fica travado em 100% numa janela que na verdade zerou. A
    /// versão anterior disto chutava uma carência de 15 minutos, o que tinha dois defeitos: se o
    /// endpoint demorasse 16 min, o painel pulava de 0% de volta pra 100%; e abrir o app 20 min
    /// depois da virada mostrava o número velho como se fosse bom.
    ///
    /// Agora são três evidências, todas objetivas, e a desconfiança só existe com as TRÊS juntas:
    ///
    /// 1. **A janela virou**: o `resets_at` desta leitura é posterior ao da leitura anterior.
    /// 2. **O número não mudou**: o percentual é idêntico ao último lido da janela anterior. Um
    ///    valor legítimo praticamente nunca nasce igualzinho ao que fechou a janela passada.
    /// 3. **Não há uso local nenhum na janela nova**: os logs desta máquina, dentro da janela
    ///    real reconstruída do `resets_at`, estão vazios — e sem token gasto o percentual honesto
    ///    é 0.
    ///
    /// A suspeita persiste (via `suspectResetsAt`/`suspectPercent` no jornal) enquanto o endpoint
    /// repetir o mesmo número, sem prazo de validade, e **evapora sozinha** assim que ele publica
    /// qualquer valor diferente ou assim que aparece uso local. Sem penhasco e sem flip-flop.
    ///
    /// A evidência 3 é também a proteção contra o falso positivo: quem usa a mesma conta em outra
    /// máquina tem percentual alto com log local vazio — mas aí o número do endpoint *muda* entre
    /// leituras, e a evidência 2 nunca fecha.
    static func reconciledWithLocalUsage(
        _ limits: [OfficialLimitInfo],
        events: [UsageEvent],
        journal: UsageObservationJournal,
        account: String,
        now: Date
    ) -> [OfficialLimitInfo] {
        limits.map { limit in
            let previous = journal.observation(account: account, label: limit.label)

            // (1) a janela virou desde a última leitura?
            let rolledOver: Bool = {
                guard let previousReset = previous?.lastResetsAt, let reset = limit.resetsAt else { return false }
                return reset > previousReset
            }()
            // (2) o endpoint repetiu o número da janela anterior?
            let frozen = rolledOver && previous?.lastPercent == limit.usedPercent
            // ...ou já tínhamos flagrado esta mesma leitura como resquício num refresh anterior.
            let stillFrozen = previous?.suspectResetsAt != nil
                && previous?.suspectResetsAt == limit.resetsAt
                && previous?.suspectPercent == limit.usedPercent
            // (3) os logs locais confirmam que nada foi gasto na janela nova?
            let noLocalUsage: Bool = {
                guard let window = AuthoritativeWindow.window(for: limit) else { return false }
                return AuthoritativeWindow.events(events, in: window).isEmpty
            }()

            let isStale = (frozen || stillFrozen) && noLocalUsage

            journal.record(
                UsageObservationJournal.Observation(
                    lastResetsAt: limit.resetsAt,
                    lastPercent: limit.usedPercent,
                    suspectResetsAt: isStale ? limit.resetsAt : nil,
                    suspectPercent: isStale ? limit.usedPercent : nil
                ),
                account: account,
                label: limit.label
            )

            guard isStale else { return limit }
            // Sem nenhum token gasto na janela nova, 0% não é um chute: é o que os logs medem.
            return OfficialLimitInfo(label: limit.label, usedPercent: 0, resetsAt: limit.resetsAt)
        }
    }

    public var sourcePath: String { reader.projectsDirectory.path }

    public var isInstalled: Bool {
        FileManager.default.fileExists(atPath: sourcePath)
    }

    public func snapshot(config: QuotaConfig) throws -> ProviderSnapshot {
        guard isInstalled else {
            return .unavailable(
                providerId: id, displayName: displayName, isInstalled: false,
                note: "Diretório \(sourcePath) não encontrado"
            )
        }

        let events = reader.readAllEvents()
        guard !events.isEmpty else {
            return .unavailable(
                providerId: id, displayName: displayName, isInstalled: true,
                note: "Nenhum evento de uso encontrado em \(sourcePath)"
            )
        }

        let account = accountReader.read()
        // Ao vivo primeiro (bate certo com claude.ai mesmo se o CLI não roda há dias); o cache
        // local de `~/.claude.json` (já filtrado por `ClaudeAccountReader` pra não mostrar janela
        // expirada) só entra se a rede falhar — offline, sem token, endpoint fora do ar etc.
        let officialLimits = Self.reconciledWithLocalUsage(
            ClaudeLiveUsageReader.read(credentialsFile: credentialsFile, now: now())
                ?? account?.officialLimits
                ?? [],
            events: events,
            journal: journal,
            account: id,
            now: now()
        )

        // A janela REAL: reconstruída do `resets_at` oficial quando existe um, e só caindo pro
        // bloco inferido dos logs quando não há nenhum. Isso é o que faz a contagem abaixo ser a
        // da janela que a Anthropic conta, e não a de um bloco que começa no primeiro evento que
        // por acaso foi registrado nesta máquina.
        guard let resolved = AuthoritativeWindow.resolve(
            officialLimits: officialLimits, events: events, now: now()
        ) else {
            return .unavailable(
                providerId: id, displayName: displayName, isInstalled: true,
                note: "Nenhum evento de uso encontrado em \(sourcePath)"
            )
        }
        let window = resolved.window
        // Contagem real: os eventos dos logs que caem dentro da janela real. Não passa pelo
        // percentual do endpoint em momento nenhum, então a defasagem da virada não a afeta —
        // numa janela recém-virada isto dá 0 token porque 0 token foi gasto, não por heurística.
        let windowEvents = AuthoritativeWindow.events(events, in: window)

        let byModel = Dictionary(grouping: windowEvents, by: \.model).map { model, events -> ProviderModelUsage in
            ProviderModelUsage(
                model: model,
                totalTokens: events.reduce(0) { $0 + $1.totalTokens },
                eventCount: events.count,
                cost: CostCalculator.totalCost(for: events),
                isEstimatedPricing: ModelPricingTable.pricing(for: model).isEstimated
            )
        }.sorted { ($0.cost ?? 0) > ($1.cost ?? 0) }

        let hourlyUsage = UsageWindowBuilder.hourlyBuckets(
            for: windowEvents,
            window: window,
            value: \.totalTokens
        )

        return ProviderSnapshot(
            providerId: id,
            displayName: displayName,
            kind: .fullTokens,
            isInstalled: true,
            windowStart: window.start,
            windowEnd: window.end,
            isActive: window.isActive(now: now()),
            totalTokens: windowEvents.reduce(0) { $0 + $1.totalTokens },
            totalCost: CostCalculator.totalCost(for: windowEvents),
            eventCount: windowEvents.count,
            byModel: byModel,
            officialLimits: officialLimits,
            note: nil,
            hourlyUsage: hourlyUsage,
            planLabel: Self.planLabel(organizationType: account?.organizationType),
            accountEmail: account?.email
        )
    }
}
