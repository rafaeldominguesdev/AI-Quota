import Foundation

/// Resolves a dot-separated key path (e.g. "payload.info.usage.input_tokens") against a JSON
/// value decoded with `JSONSerialization` (nested `[String: Any]` dictionaries). This is what
/// lets `providers.json` describe arbitrary nested log shapes without any Swift code.
enum JSONPathResolver {
    static func value(at path: String, in json: Any) -> Any? {
        guard !path.isEmpty else { return nil }
        var current: Any = json
        for component in path.split(separator: ".") {
            guard let dict = current as? [String: Any], let next = dict[String(component)] else {
                return nil
            }
            current = next
        }
        return current
    }

    static func string(at path: String, in json: Any) -> String? {
        switch value(at: path, in: json) {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    static func int(at path: String, in json: Any) -> Int? {
        (value(at: path, in: json) as? NSNumber)?.intValue
    }

    static func double(at path: String, in json: Any) -> Double? {
        (value(at: path, in: json) as? NSNumber)?.doubleValue
    }
}
