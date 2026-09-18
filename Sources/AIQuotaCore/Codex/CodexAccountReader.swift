import Foundation

/// Lê a conta logada do Codex em `~/.codex/auth.json`. O e-mail não vem em texto puro ali — só
/// dentro do claim `email` do JWT `tokens.id_token` (o mesmo ID token que o login OAuth do
/// próprio Codex guarda), então decodificamos o payload do token à mão. Sem verificação de
/// assinatura: é o próprio arquivo do usuário, no disco dele, só para leitura de um claim.
public struct CodexAccountReader: Sendable {
    public struct Account: Equatable, Sendable {
        public let email: String?
    }

    private let authFile: URL

    public init(
        authFile: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")
    ) {
        self.authFile = authFile
    }

    public func read() -> Account? {
        guard let data = try? Data(contentsOf: authFile),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = root["tokens"] as? [String: Any],
              let idToken = tokens["id_token"] as? String,
              let payload = Self.decodeJWTPayload(idToken) else {
            return nil
        }
        return Account(email: payload["email"] as? String)
    }

    /// Um JWT é `header.payload.assinatura` em base64url; só o `payload` interessa aqui.
    private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
