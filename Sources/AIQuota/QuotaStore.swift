import Foundation
import Combine
import AIQuotaCore

/// Estado observável consumido pelo painel SwiftUI e pelo NSStatusItem.
///
/// `@unchecked Sendable`: mutações só acontecem na main queue (dentro do `DispatchQueue.main.async`
/// em `refreshNow()`), e a leitura pelas views SwiftUI/AppKit também é sempre na main thread — o
/// trabalho pesado de I/O roda numa fila de fundo, mas nunca toca as propriedades `@Published`
/// diretamente.
final class QuotaStore: ObservableObject, @unchecked Sendable {
    @Published private(set) var snapshot: QuotaSnapshot?
    @Published private(set) var cursorUsageByModel: [String: Int] = [:]
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isRefreshing = false

    /// Chamado na main thread sempre que um novo snapshot é publicado, para o NSStatusItem
    /// atualizar o título sem precisar observar o Combine publisher diretamente.
    var onSnapshotUpdated: ((QuotaSnapshot?) -> Void)?

    private let claudeReader = ClaudeCodeLogReader()
    private let cursorReader = CursorUsageReader()
    private let codexReader = CodexUsageReader()
    private let backgroundQueue = DispatchQueue(label: "dev.rafaeldomingues.aiquota.refresh", qos: .userInitiated)
    private var timer: Timer?

    func startAutoRefresh(interval: TimeInterval = 30) {
        refreshNow()
        stopAutoRefresh()
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshNow()
        }
        // .common garante que o timer continue disparando mesmo com o popover aberto
        // (o run loop entra em outros modos durante tracking de UI).
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    /// Varre os logs em background e publica o resultado na main thread. A varredura
    /// percorre potencialmente centenas de arquivos .jsonl e não pode rodar na main thread.
    func refreshNow() {
        isRefreshing = true

        let claudeReader = self.claudeReader
        let cursorReader = self.cursorReader
        let codexReader = self.codexReader

        backgroundQueue.async { [weak self] in
            let events = claudeReader.readAllEvents()
            let newSnapshot = QuotaSnapshotBuilder.build(from: events)
            let windowStart = newSnapshot?.windowStart ?? Date().addingTimeInterval(-5 * 3600)
            let cursorCounts = cursorReader.usageCountByModel(from: windowStart)
            // Checado por completude; o núcleo ainda não expõe dados de uso reais do Codex
            // (formato não documentado — ver docs/DATA-SOURCES.md), então não há nada para exibir.
            _ = codexReader.checkAvailability()

            DispatchQueue.main.async {
                guard let self else { return }
                self.snapshot = newSnapshot
                self.cursorUsageByModel = cursorCounts
                self.lastUpdated = Date()
                self.isRefreshing = false
                self.onSnapshotUpdated?(newSnapshot)
            }
        }
    }
}
