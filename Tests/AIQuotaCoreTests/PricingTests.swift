import Testing
import Foundation
@testable import AIQuotaCore

@Suite("Precificação")
struct PricingTests {

    @Test("Casamento de modelo por prefixo")
    func modelMatchesByPrefix() {
        let opus = ModelPricingTable.pricing(for: "claude-opus-5-20260115")
        #expect(opus.inputPerMillion == 5)
        #expect(opus.outputPerMillion == 25)
        #expect(opus.isEstimated == false)

        let haiku = ModelPricingTable.pricing(for: "claude-haiku-4-5-20251001")
        #expect(haiku.inputPerMillion == 1)
        #expect(haiku.outputPerMillion == 5)
    }

    @Test("Modelo desconhecido cai no fallback do Sonnet e é marcado como estimado")
    func unknownModelFallsBackToSonnetEstimate() {
        let pricing = ModelPricingTable.pricing(for: "gpt-5-turbo")
        #expect(pricing.inputPerMillion == 2)
        #expect(pricing.outputPerMillion == 10)
        #expect(pricing.isEstimated == true)
    }

    @Test("Custo de input e output simples (sem cache)")
    func plainInputOutputCost() {
        let event = makeEvent(model: "claude-sonnet-5", inputTokens: 1_000_000, outputTokens: 1_000_000)
        let cost = CostCalculator.cost(for: event)
        // 1M de input a $2 + 1M de output a $10 = $12
        #expect(abs(cost - 12.0) < 0.0001)
    }

    @Test("Custo de cache write de 5 minutos usa multiplicador 1.25x sobre o preço de input")
    func cacheWrite5mCost() {
        let event = makeEvent(
            model: "claude-sonnet-5",
            inputTokens: 0,
            outputTokens: 0,
            cacheCreation5mTokens: 1_000_000
        )
        let cost = CostCalculator.cost(for: event)
        // 1M tokens a $2 * 1.25 = $2.50
        #expect(abs(cost - 2.5) < 0.0001)
    }

    @Test("Custo de cache write de 1 hora usa multiplicador 2.0x sobre o preço de input")
    func cacheWrite1hCost() {
        let event = makeEvent(
            model: "claude-sonnet-5",
            inputTokens: 0,
            outputTokens: 0,
            cacheCreation1hTokens: 1_000_000
        )
        let cost = CostCalculator.cost(for: event)
        // 1M tokens a $2 * 2.0 = $4.00
        #expect(abs(cost - 4.0) < 0.0001)
    }

    @Test("Custo de cache read usa multiplicador 0.1x sobre o preço de input")
    func cacheReadCost() {
        let event = makeEvent(
            model: "claude-sonnet-5",
            inputTokens: 0,
            outputTokens: 0,
            cacheReadInputTokens: 1_000_000
        )
        let cost = CostCalculator.cost(for: event)
        // 1M tokens a $2 * 0.1 = $0.20
        #expect(abs(cost - 0.2) < 0.0001)
    }

    @Test("Custo combinado: input, output, cache write (5m e 1h) e cache read")
    func combinedCost() {
        let event = makeEvent(
            model: "claude-opus-5",
            inputTokens: 1_000_000,
            outputTokens: 1_000_000,
            cacheReadInputTokens: 1_000_000,
            cacheCreation5mTokens: 1_000_000,
            cacheCreation1hTokens: 1_000_000
        )
        let cost = CostCalculator.cost(for: event)
        // input: 5 + output: 25 + cache5m: 5*1.25=6.25 + cache1h: 5*2.0=10 + cacheRead: 5*0.1=0.5
        let expected = 5.0 + 25.0 + 6.25 + 10.0 + 0.5
        #expect(abs(cost - expected) < 0.0001)
    }
}
