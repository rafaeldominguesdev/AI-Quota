import Foundation
import SQLite3

/// Um uso registrado pelo Cursor. Não há tokens nem custo disponíveis nessa fonte
/// (ver docs/DATA-SOURCES.md) — apenas contagem de usos por modelo.
public struct CursorUsageRecord: Equatable, Sendable {
    public let model: String
    public let timestamp: Date
}

/// Lê ~/.cursor/ai-tracking/ai-code-tracking.db em modo somente leitura.
///
/// O Cursor NÃO expõe input_tokens/output_tokens nesse banco — apenas hashes de código
/// gerado com modelo e timestamp. Por isso só expomos contagem de usos por modelo,
/// nunca custo ou tokens para essa fonte.
public struct CursorUsageReader: Sendable {
    public let databasePath: String

    public init(
        databasePath: String = (NSString(string: "~/.cursor/ai-tracking/ai-code-tracking.db"))
            .expandingTildeInPath
    ) {
        self.databasePath = databasePath
    }

    /// Retorna `[]` sem erro se o arquivo não existir.
    public func readUsageRecords() -> [CursorUsageRecord] {
        guard FileManager.default.fileExists(atPath: databasePath) else { return [] }

        var db: OpaquePointer?
        // SQLITE_OPEN_READONLY: nunca escrevemos no banco de outra ferramenta.
        guard sqlite3_open_v2(databasePath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let db else {
            return []
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT model, createdAt FROM ai_code_hashes WHERE model IS NOT NULL AND createdAt IS NOT NULL;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var records: [CursorUsageRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let modelCString = sqlite3_column_text(statement, 0) else { continue }
            let model = String(cString: modelCString)
            let createdAtMs = sqlite3_column_int64(statement, 1)
            let timestamp = Date(timeIntervalSince1970: Double(createdAtMs) / 1000)
            records.append(CursorUsageRecord(model: model, timestamp: timestamp))
        }
        return records
    }

    /// Contagem de usos por modelo dentro de uma janela de tempo.
    public func usageCountByModel(from start: Date, to end: Date = Date()) -> [String: Int] {
        let records = readUsageRecords().filter { $0.timestamp >= start && $0.timestamp <= end }
        return Dictionary(grouping: records, by: { $0.model }).mapValues { $0.count }
    }
}
