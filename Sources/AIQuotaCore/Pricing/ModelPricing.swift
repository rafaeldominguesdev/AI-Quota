import Foundation

/// Preço de um modelo em USD por 1 milhão de tokens.
public struct ModelPricing: Equatable, Sendable {
    public let inputPerMillion: Double
    public let outputPerMillion: Double
    /// `true` quando o preço é um fallback (modelo desconhecido), não um valor confirmado.
    public let isEstimated: Bool

    public init(inputPerMillion: Double, outputPerMillion: Double, isEstimated: Bool = false) {
        self.inputPerMillion = inputPerMillion
        self.outputPerMillion = outputPerMillion
        self.isEstimated = isEstimated
    }
}

/// Tabela de preços por modelo, fácil de editar quando a Anthropic mudar os valores.
/// Todos os valores em USD por 1 milhão de tokens.
public enum ModelPricingTable {
    /// Multiplicadores de cache aplicados sobre o preço de INPUT do modelo.
    public static let cacheWrite5mMultiplier = 1.25
    public static let cacheWrite1hMultiplier = 2.0
    public static let cacheReadMultiplier = 0.1

    /// Ordem importa apenas se um prefixo puder ser prefixo de outro; hoje os três
    /// prefixos abaixo são mutuamente exclusivos.
    private static let table: [(prefix: String, pricing: ModelPricing)] = [
        ("claude-opus-5", ModelPricing(inputPerMillion: 5, outputPerMillion: 25)),
        ("claude-sonnet-5", ModelPricing(inputPerMillion: 2, outputPerMillion: 10)),
        ("claude-haiku-4-5", ModelPricing(inputPerMillion: 1, outputPerMillion: 5))
    ]

    /// Fallback para modelo desconhecido: usa o preço do Sonnet e marca como estimado,
    /// para que a UI possa sinalizar que o custo é aproximado.
    private static let fallback = ModelPricing(inputPerMillion: 2, outputPerMillion: 10, isEstimated: true)

    /// Casa o modelo por prefixo (ex.: "claude-opus-5" casa com "claude-opus-5-20260101").
    public static func pricing(for model: String) -> ModelPricing {
        for entry in table where model.hasPrefix(entry.prefix) {
            return entry.pricing
        }
        return fallback
    }
}
