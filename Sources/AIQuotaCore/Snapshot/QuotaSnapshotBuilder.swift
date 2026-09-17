import Foundation

public enum QuotaSnapshotBuilder {
    /// Constrói o snapshot a partir do último bloco de 5h observado nos eventos.
    /// Retorna `nil` se não houver nenhum evento (nunca usou o Claude Code).
    public static func build(
        from events: [UsageEvent],
        config: QuotaConfig = .defaultConfig,
        now: Date = Date()
    ) -> QuotaSnapshot? {
        let blocks = FiveHourBlockBuilder.buildBlocks(from: events)
        guard let lastBlock = blocks.last else { return nil }
        return snapshot(for: lastBlock, config: config, now: now)
    }

    private static func snapshot(for block: FiveHourBlock, config: QuotaConfig, now: Date) -> QuotaSnapshot {
        let cost = block.totalCost
        let percent = min(100, (cost / config.referenceCostCeilingUSD) * 100)

        let state: QuotaState
        if percent >= config.dangerThresholdPercent {
            state = .danger
        } else if percent >= config.warningThresholdPercent {
            state = .warning
        } else {
            state = .safe
        }

        return QuotaSnapshot(
            generatedAt: now,
            windowStart: block.start,
            windowEnd: block.end,
            isActive: block.isActive(now: now),
            usagePercent: percent,
            state: state,
            totalTokens: block.totalTokens,
            totalCost: cost,
            resetAt: block.end,
            remainingSeconds: block.remaining(now: now),
            remainingTimeFormatted: formatRemaining(block.remaining(now: now)),
            byModel: modelBreakdown(for: block)
        )
    }

    private static func modelBreakdown(for block: FiveHourBlock) -> [ModelUsageBreakdown] {
        block.eventsByModel.map { model, events in
            ModelUsageBreakdown(
                model: model,
                totalTokens: events.reduce(0) { $0 + $1.totalTokens },
                cost: CostCalculator.totalCost(for: events),
                isEstimatedPricing: ModelPricingTable.pricing(for: model).isEstimated
            )
        }.sorted { $0.cost > $1.cost }
    }

    private static func formatRemaining(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h\(String(format: "%02d", minutes))m"
    }
}
