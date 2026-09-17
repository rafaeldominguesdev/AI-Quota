import Foundation

/// Raw shape of a line in `~/.codex/sessions/**/*.jsonl`, confirmed against real files on disk
/// (2026-09). Lines have different `type`s ("event_msg", "session_meta", "turn_context",
/// "response_item", "token_usage_record", ...); this single permissive struct decodes whichever
/// fields are relevant across all of them, leaving the rest `nil`.
struct CodexSessionLine: Decodable {
    let timestamp: String?
    let type: String?
    let payload: CodexPayload?
}

struct CodexPayload: Decodable {
    /// Present on `event_msg` lines: "token_count", "item_completed", "task_started", etc.
    let type: String?
    /// Present on `event_msg` / "token_count" payloads. Can be `null` (seen when only credits
    /// info is being reported, with no token usage yet).
    let info: CodexTokenInfo?
    let rate_limits: CodexRateLimitsPayload?
    /// Present directly on `turn_context` payloads (confirmed in real files) — the simplest,
    /// most reliable place to read the active model from.
    let model: String?
}

/// `total_token_usage` is CUMULATIVE for the whole session (can reach tens of millions of
/// tokens by the end of a long session). `last_token_usage` is the delta for that single turn.
/// Summing usage across events must always use `last_token_usage`, never `total_token_usage`.
struct CodexTokenInfo: Decodable {
    let total_token_usage: CodexTokenCounts?
    let last_token_usage: CodexTokenCounts?
    let model_context_window: Int?
}

struct CodexTokenCounts: Decodable {
    let input_tokens: Int?
    let cached_input_tokens: Int?
    let cache_write_input_tokens: Int?
    let output_tokens: Int?
    let reasoning_output_tokens: Int?
    let total_tokens: Int?
}

/// Codex's own rate-limit reporting. `primary`/`secondary` are `null` most of the time (seen on
/// most sessions) but ARE populated on some — that's an official quota, strictly better than our
/// own cost-based estimate whenever it's available.
struct CodexRateLimitsPayload: Decodable {
    let limit_id: String?
    let primary: CodexRateLimitWindowPayload?
    let secondary: CodexRateLimitWindowPayload?
    let plan_type: String?
}

struct CodexRateLimitWindowPayload: Decodable {
    let used_percent: Double?
    let window_minutes: Int?
    /// Unix seconds.
    let resets_at: Int?
}
