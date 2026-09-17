import Foundation

/// Lê um arquivo linha a linha em blocos, sem carregar o arquivo inteiro na memória.
/// Os .jsonl do Claude Code podem ter dezenas de MB (sessões longas com "thinking" grande).
final class FileLineReader {
    private let handle: FileHandle
    private var buffer = Data()
    private var reachedEOF = false
    private let chunkSize = 256 * 1024
    private let newline: UInt8 = 0x0A

    init?(path: String) {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        self.handle = handle
    }

    /// Retorna a próxima linha (sem o `\n`), ou `nil` no fim do arquivo.
    func nextLine() -> String? {
        while true {
            if let newlineIndex = buffer.firstIndex(of: newline) {
                let lineData = buffer.subdata(in: buffer.startIndex..<newlineIndex)
                buffer.removeSubrange(buffer.startIndex...newlineIndex)
                return String(data: lineData, encoding: .utf8)
            }

            if reachedEOF {
                guard !buffer.isEmpty else { return nil }
                let remaining = buffer
                buffer.removeAll()
                return String(data: remaining, encoding: .utf8)
            }

            let chunk = handle.readData(ofLength: chunkSize)
            if chunk.isEmpty {
                reachedEOF = true
            } else {
                buffer.append(chunk)
            }
        }
    }

    func close() {
        try? handle.close()
    }

    deinit {
        close()
    }
}
