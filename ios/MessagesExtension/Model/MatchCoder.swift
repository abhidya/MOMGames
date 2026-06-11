import Foundation

/// Encodes a `MatchEnvelope` into a URL-safe payload carried by `MSMessage.url`
/// and decodes it back. We use base64url (no `+`, `/`, or `=`) so the value
/// survives URL query round-tripping intact.
enum MatchCoder {
    private static let host = "momgames.app"

    static func encode(_ envelope: MatchEnvelope) -> URL {
        let data = (try? JSONEncoder().encode(envelope)) ?? Data()
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/match"
        components.queryItems = [URLQueryItem(name: "m", value: data.base64URLEncodedString())]
        // `url` is non-nil for these fixed, valid components.
        return components.url ?? URL(string: "https://\(host)/match")!
    }

    static func decode(_ url: URL?) -> MatchEnvelope? {
        guard
            let url,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let value = components.queryItems?.first(where: { $0.name == "m" })?.value,
            let data = Data(base64URLEncoded: value)
        else { return nil }
        return try? JSONDecoder().decode(MatchEnvelope.self, from: data)
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64.append(String(repeating: "=", count: padding))
        self.init(base64Encoded: base64)
    }
}
