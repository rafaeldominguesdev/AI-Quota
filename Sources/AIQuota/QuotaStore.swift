import Foundation
import Combine
import AIQuotaCore

/// Onde cada provedor é lido em disco. Mostrado na tela de PROVEDORES, para o usuário saber
/// de onde o número dele saiu (e onde mexer quando não sair nada).
struct ProviderSource: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let sourcePath: String
    let kind: ProviderDataKind
    let isInstalled: Bool
}

/// Estado observável consumido pelo painel SwiftUI e pelo NSStatusItem.
///
/// Isolado na main actor: todas as propriedades `@Published` são lidas por views SwiftUI e pelo
/// NSStatusItem, que vivem na main thread. A varredura dos logs (centenas de arquivos .jsonl,
/// mais um banco SQLite) roda numa `Task.detached` e só volta para cá no `apply(...)`, que é
/// `@MainActor` — a interface nunca trava esperando I/O.
@MainActor
final class QuotaStore: ObservableObject {
    @Published private(set) var overview: QuotaOverview?
    @Published private(set) var sources: [ProviderSource] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isRefreshing = false

    /// Chamado na main thread a cada novo overview, para o NSStatusItem redesenhar o medidor
    /// sem precisar assinar o publisher do Combine.
    var onOverviewUpdated: ((QuotaOverview?) -> Void)?

    private var timer: Timer?

    // MARK: - Ciclo de atualização

    func startAutoRefresh(interval: TimeInterval = 30) {
        refreshNow()
        stopAutoRefresh()
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            // O timer foi adicionado ao RunLoop.main, então este bloco sempre roda na main
            // thread — `assumeIsolated` afirma exatamente isso, sem abrir mão da checagem.
            MainActor.assumeIsolated {
                self?.refreshNow()
            }
        }
        // .common garante que o timer continue disparando com o popover aberto (o run loop
        // entra em outros modos durante tracking de UI).
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    func refreshNow() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task.detached(priority: .userInitiated) { [weak self] in
            // O registry é reconstruído a cada varredura de propósito: assim uma edição em
            // ~/.config/ai-quota/providers.json passa a valer sem reiniciar o app.
            let registry = ProviderRegistry()
            let overview = registry.buildOverview()
            let sources = registry.providers.map {
                ProviderSource(
                    id: $0.id,
                    displayName: $0.displayName,
                    sourcePath: $0.sourcePath,
                    kind: $0.kind,
                    isInstalled: $0.isInstalled
                )
            }
            await self?.apply(overview: overview, sources: sources)
        }
    }

    private func apply(overview: QuotaOverview, sources: [ProviderSource]) {
        self.overview = overview
        self.sources = sources
        self.lastUpdated = Date()
        self.isRefreshing = false
        self.onOverviewUpdated?(overview)
    }

    // MARK: - Derivados para a UI

    var primary: ProviderPresentation? {
        guard let overview, let snapshot = overview.primary else { return nil }
        return ProviderPresentation(snapshot: snapshot, isPrimary: true)
    }

    /// Provedores na ordem em que devem aparecer: o principal primeiro, depois quem tem
    /// percentual, depois quem tem algum outro dado, e por último as linhas vazias.
    var providerRows: [ProviderPresentation] {
        guard let overview else { return [] }
        return overview.providers
            .map { ProviderPresentation(snapshot: $0, isPrimary: $0.providerId == overview.primaryProviderId) }
            .sorted { lhs, rhs in
                if lhs.isPrimary != rhs.isPrimary { return lhs.isPrimary }
                let lhsRank = Self.rank(lhs)
                let rhsRank = Self.rank(rhs)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.displayName < rhs.displayName
            }
    }

    /// Provedores conectados de verdade — instalados E com algo real para mostrar: uma janela de
    /// cota (limite oficial ou custo estimado) OU, para quem não expõe cota, ao menos uma
    /// contagem de uso (`fallbackValue`, o "N usos" do Cursor e do Antigravity). `isInstalled`
    /// sozinho não basta: o CLI pode estar no disco sem nenhum uso, e aí não há o que desenhar.
    /// Na mesma ordem de `providerRows`; é o que a barra de menu mostra, as IAs que o usuário
    /// realmente usa, não a lista inteira de provedores suportados.
    var connectedProviders: [ProviderPresentation] {
        providerRows.filter {
            $0.snapshot.isInstalled && (!$0.windows.isEmpty || $0.fallbackValue != nil)
        }
    }

    private static func rank(_ presentation: ProviderPresentation) -> Int {
        if presentation.percent != nil { return 0 }
        if presentation.fallbackValue != nil { return 1 }
        return 2
    }

    var configWarnings: [String] { overview?.configWarnings ?? [] }

    /// A única linha de resumo do painel: custo e tokens somados de todas as IAs que reportam
    /// esses dados. `nil` quando nenhuma reporta, para a linha simplesmente não existir.
    var summaryLine: String? {
        guard let overview else { return nil }

        let cost = overview.providers.compactMap(\.totalCost).reduce(0, +)
        let tokens = overview.providers.reduce(0) { $0 + $1.totalTokens }

        var parts: [String] = []
        if cost > 0 { parts.append(QuotaFormatting.cost(cost)) }
        if tokens > 0 { parts.append(QuotaFormatting.compactTokens(tokens) + " tokens") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
