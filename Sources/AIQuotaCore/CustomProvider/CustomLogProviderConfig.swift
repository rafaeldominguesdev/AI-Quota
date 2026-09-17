import Foundation

/// Optional flat per-1M-token pricing for a custom provider, so the user can get a cost estimate
/// for CLIs that bill by usage instead of a flat subscription.
public struct CustomProviderPricing: Equatable, Sendable {
    public let inputPer1M: Double
    public let outputPer1M: Double
}

/// A user-defined provider described entirely in `providers.json` — no recompilation needed to
/// add GLM, Qwen, DeepSeek, or anything else that writes JSONL logs.
public struct CustomLogProviderConfig: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let enabled: Bool
    public let logGlob: String
    public let timestampPath: String
    public let modelPath: String?
    public let inputTokensPath: String?
    public let outputTokensPath: String?
    public let totalTokensPath: String?
    /// If true, the token fields are running totals per session file (like Codex's own
    /// `total_token_usage`) and must be diffed into per-event deltas instead of summed as-is.
    public let cumulative: Bool
    public let pricing: CustomProviderPricing?

    /// Parses one element of `providers.json`'s `"custom"` array. Returns a human-readable error
    /// instead of throwing, so the caller can skip just this one entry and keep the rest —
    /// a malformed custom provider must never take down the whole app.
    static func parse(_ raw: [String: Any]) -> ConfigParseResult {
        guard let id = (raw["id"] as? String)?.trimmedNonEmpty else {
            return .failure("provedor customizado sem \"id\" válido (string não vazia)")
        }
        guard let displayName = (raw["displayName"] as? String)?.trimmedNonEmpty else {
            return .failure("provedor \"\(id)\" sem \"displayName\" válido (string não vazia)")
        }
        guard let logGlob = (raw["logGlob"] as? String)?.trimmedNonEmpty else {
            return .failure("provedor \"\(id)\" sem \"logGlob\" válido (string não vazia)")
        }
        guard let timestampPath = (raw["timestampPath"] as? String)?.trimmedNonEmpty else {
            return .failure("provedor \"\(id)\" sem \"timestampPath\" válido (string não vazia)")
        }

        let enabled = (raw["enabled"] as? Bool) ?? true
        let modelPath = (raw["modelPath"] as? String)?.trimmedNonEmpty
        let inputTokensPath = (raw["inputTokensPath"] as? String)?.trimmedNonEmpty
        let outputTokensPath = (raw["outputTokensPath"] as? String)?.trimmedNonEmpty
        let totalTokensPath = (raw["totalTokensPath"] as? String)?.trimmedNonEmpty
        let cumulative = (raw["cumulative"] as? Bool) ?? false

        var pricing: CustomProviderPricing?
        if let pricingRaw = raw["pricing"] as? [String: Any] {
            guard let inputPer1M = (pricingRaw["inputPer1M"] as? NSNumber)?.doubleValue,
                  let outputPer1M = (pricingRaw["outputPer1M"] as? NSNumber)?.doubleValue else {
                return .failure("provedor \"\(id)\" tem \"pricing\" malformado (precisa de inputPer1M e outputPer1M numéricos)")
            }
            pricing = CustomProviderPricing(inputPer1M: inputPer1M, outputPer1M: outputPer1M)
        }

        return .success(
            CustomLogProviderConfig(
                id: id,
                displayName: displayName,
                enabled: enabled,
                logGlob: logGlob,
                timestampPath: timestampPath,
                modelPath: modelPath,
                inputTokensPath: inputTokensPath,
                outputTokensPath: outputTokensPath,
                totalTokensPath: totalTokensPath,
                cumulative: cumulative,
                pricing: pricing
            )
        )
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Small stand-in for `Result<CustomLogProviderConfig, String>` — `String` doesn't conform to
/// `Error`, and a full error type would be overkill for messages that only ever get displayed.
enum ConfigParseResult {
    case success(CustomLogProviderConfig)
    case failure(String)
}
