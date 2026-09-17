import Foundation

/// How much can be trusted about a provider's usage data.
public enum ProviderDataKind: String, Codable, Sendable {
    /// Separate input/output tokens are available, so cost can be estimated.
    case fullTokens
    /// Only a total token count is available (no input/output split), so cost can't be split.
    case tokensOnly
    /// No token counts at all — only how many interactions/sessions happened.
    case countOnly
    /// Installed but with no readable usage data, or not installed at all.
    case unavailable
}
