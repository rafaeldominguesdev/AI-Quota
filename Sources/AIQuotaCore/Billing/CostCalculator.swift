import Foundation

/// Calcula o custo em USD de eventos de uso, aplicando os multiplicadores de cache.
public enum CostCalculator {
    public static func cost(for event: UsageEvent) -> Double {
        let pricing = ModelPricingTable.pricing(for: event.model)
        return cost(for: event, pricing: pricing)
    }

    public static func cost(for event: UsageEvent, pricing: ModelPricing) -> Double {
        let million = 1_000_000.0

        let inputCost = Double(event.inputTokens) * pricing.inputPerMillion / million
        let cache5mCost = Double(event.cacheCreation5mTokens)
            * pricing.inputPerMillion * ModelPricingTable.cacheWrite5mMultiplier / million
        let cache1hCost = Double(event.cacheCreation1hTokens)
            * pricing.inputPerMillion * ModelPricingTable.cacheWrite1hMultiplier / million
        let cacheReadCost = Double(event.cacheReadInputTokens)
            * pricing.inputPerMillion * ModelPricingTable.cacheReadMultiplier / million
        let outputCost = Double(event.outputTokens) * pricing.outputPerMillion / million

        return inputCost + cache5mCost + cache1hCost + cacheReadCost + outputCost
    }

    public static func totalCost(for events: [UsageEvent]) -> Double {
        events.reduce(0) { $0 + cost(for: $1) }
    }
}
