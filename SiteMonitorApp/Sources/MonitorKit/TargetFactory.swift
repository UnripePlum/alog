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
    public init() {}

    public func make(name: String, url: String) throws -> Target {
        let normalized = Self.normalizeURL(url)
        guard !normalized.isEmpty else { throw TargetFactoryError.emptyURL }
        guard Self.isValidHTTPURL(normalized) else { throw TargetFactoryError.invalidURL }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.isEmpty ? Self.hostLabel(from: normalized) : trimmedName

        return Target(
            name: displayName,
            url: normalized,
            actions: Defaults.starterActions()
        )
    }

    /// 앞뒤 공백 제거. 스킴이 없으면 `https://` 를 붙인다.
    public static func normalizeURL(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        if trimmed.contains("://") { return trimmed }
        return "https://\(trimmed)"
    }

    public static func isValidHTTPURL(_ raw: String) -> Bool {
        let normalized = normalizeURL(raw)
        guard let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty
        else { return false }
        return true
    }

    public static func hostLabel(from urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }
}
