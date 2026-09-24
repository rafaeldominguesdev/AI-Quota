import Foundation

/// A cota do Cursor lida da web (`CursorWebSession`, no target do app — WebKit não entra aqui)
/// grava um arquivo simples que este lado só lê. Nada de acoplar `AIQuotaCore` a WebKit/AppKit: o
/// `aiquota-cli` também depende deste target, e não devia arrastar uma dependência de UI só para
/// ler um número que outro processo já calculou.
public struct CursorWebUsageCache: Codable, Equatable, Sendable {
    public let percentUsed: Double
    public let capturedAt: Date

    public init(percentUsed: Double, capturedAt: Date) {
        self.percentUsed = percentUsed
        self.capturedAt = capturedAt
    }

    public static let defaultFile = ProvidersConfigStore.defaultDirectory.appendingPathComponent("cursor-web-usage.json")

    /// Uma leitura raspada da web só vale por pouco tempo: diferente da cota oficial por API, essa
    /// aqui pode ficar desatualizada sem nenhum aviso de "expirou". Mostrar um número de 3 dias
    /// atrás como se fosse de agora seria pior que não mostrar nada.
    public static let maxAge: TimeInterval = 30 * 60

    public static func load(from url: URL = defaultFile, now: Date = Date()) -> CursorWebUsageCache? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let cache = try? decoder.decode(CursorWebUsageCache.self, from: data) else { return nil }
        guard now.timeIntervalSince(cache.capturedAt) < maxAge else { return nil }
        return cache
    }

    @discardableResult
    public static func save(_ cache: CursorWebUsageCache, to url: URL = defaultFile) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(cache).write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
