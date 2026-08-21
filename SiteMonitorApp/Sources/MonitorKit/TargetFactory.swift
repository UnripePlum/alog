import Foundation

/// 사용자 입력으로 모니터링 대상을 만드는 계약.
/// UI/컨트롤러는 이 프로토콜만 의존한다.
public protocol TargetCreating: Sendable {
    /// 이름·URL로 대상을 만든다. 기본 점검 동작을 붙인다.
    func make(name: String, url: String) throws -> Target
}

/// `TargetCreating.make` 가 거부하는 입력.
public enum TargetFactoryError: Error, Equatable, Sendable {
    case emptyURL
    case invalidURL
}

public struct DefaultTargetFactory: TargetCreating {
    /// `host:port` 같은 입력을 스킴으로 오인하지 않기 위한 알려진 URI 스킴.
    private static let knownSchemes: Set<String> = [
        "http", "https", "mailto", "javascript", "file", "ftp",
        "data", "about", "blob", "ws", "wss",
    ]

    public init() {}

    public func make(name: String, url: String) throws -> Target {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TargetFactoryError.emptyURL }
        guard Self.isValidHTTPURL(trimmed) else { throw TargetFactoryError.invalidURL }
        let normalized = Self.normalizeURL(trimmed)

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.isEmpty ? Self.hostLabel(from: normalized) : trimmedName

        return Target(
            name: displayName,
            url: normalized,
            actions: Defaults.starterActions()
        )
    }

    /// 앞뒤 공백 제거. 알려진 스킴이 없으면 `https://` 를 붙인다.
    public static func normalizeURL(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        if explicitScheme(of: trimmed) != nil { return trimmed }
        return "https://\(trimmed)"
    }

    public static func isValidHTTPURL(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if let scheme = explicitScheme(of: trimmed) {
            guard scheme == "http" || scheme == "https" else { return false }
            guard hasSchemeSlashSlash(trimmed) else { return false }
        }
        return httpHostOK(normalizeURL(trimmed))
    }

    public static func hostLabel(from urlString: String) -> String {
        URLComponents(string: urlString)?.host ?? urlString
    }

    private static func explicitScheme(of raw: String) -> String? {
        guard let colon = raw.firstIndex(of: ":") else { return nil }
        let scheme = String(raw[..<colon]).lowercased()
        guard knownSchemes.contains(scheme) else { return nil }
        return scheme
    }

    private static func hasSchemeSlashSlash(_ raw: String) -> Bool {
        guard let colon = raw.firstIndex(of: ":") else { return false }
        return raw[raw.index(after: colon)...].hasPrefix("//")
    }

    private static func httpHostOK(_ urlString: String) -> Bool {
        guard let components = URLComponents(string: urlString),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              host.contains(where: { $0.isLetter || $0.isNumber }),
              components.user == nil,
              components.password == nil
        else { return false }
        return true
    }
}
