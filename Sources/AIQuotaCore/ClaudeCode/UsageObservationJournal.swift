import Foundation

/// A memória mínima que faltava ao app.
///
/// O AI Quota é stateless por natureza: cada varredura de 30s reconstrói tudo a partir dos logs e
/// joga fora. É exatamente essa falta de memória que obrigava a detecção de defasagem do endpoint
/// a se apoiar num relógio — sem lembrar da leitura anterior, a única pergunta possível era "faz
/// menos de 15 min que a janela virou?", que é um chute com prazo de validade.
///
/// Guardando a última leitura por conta e por janela, a pergunta vira objetiva e sem relógio:
/// **o número mudou?** Se o `resets_at` é novo mas o percentual é idêntico ao da janela anterior,
/// é resquício — dá na mesma se passaram 3 ou 40 minutos. E a desconfiança acaba sozinha no
/// instante em que o endpoint publica um valor diferente.
public final class UsageObservationJournal: @unchecked Sendable {
    public struct Observation: Codable, Equatable, Sendable {
        /// Última leitura vista, seja ela confiável ou não.
        public var lastResetsAt: Date?
        public var lastPercent: Double
        /// Janela já flagrada como resquício da anterior. Enquanto o endpoint repetir
        /// `suspectPercent` para este mesmo `suspectResetsAt`, seguimos desconfiando — sem prazo.
        public var suspectResetsAt: Date?
        public var suspectPercent: Double?

        public init(
            lastResetsAt: Date? = nil,
            lastPercent: Double = 0,
            suspectResetsAt: Date? = nil,
            suspectPercent: Double? = nil
        ) {
            self.lastResetsAt = lastResetsAt
            self.lastPercent = lastPercent
            self.suspectResetsAt = suspectResetsAt
            self.suspectPercent = suspectPercent
        }
    }

    public static let defaultFile = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/AIQuota/usage-journal.json")

    public static let shared = UsageObservationJournal()

    private let file: URL
    private let lock = NSLock()
    /// conta → rótulo da janela → observação.
    private var entries: [String: [String: Observation]]
    private var loaded = false

    public init(file: URL = UsageObservationJournal.defaultFile) {
        self.file = file
        self.entries = [:]
    }

    // MARK: - Leitura / escrita

    public func observation(account: String, label: String) -> Observation? {
        lock.lock(); defer { lock.unlock() }
        loadIfNeeded()
        return entries[account]?[label]
    }

    public func record(_ observation: Observation, account: String, label: String) {
        lock.lock(); defer { lock.unlock() }
        loadIfNeeded()
        entries[account, default: [:]][label] = observation
        persist()
    }

    // MARK: - Persistência

    /// Carrega uma vez por processo. Um arquivo corrompido ou de uma versão futura simplesmente
    /// começa vazio: o pior caso é confiar no endpoint por um refresh, nunca quebrar o app.
    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: file) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([String: [String: Observation]].self, from: data)) ?? [:]
    }

    /// Escrita best-effort: se falhar (disco cheio, sandbox, permissão), o app segue funcionando
    /// sem memória — volta a confiar no endpoint, que é o comportamento pré-jornal.
    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: file, options: .atomic)
    }
}
