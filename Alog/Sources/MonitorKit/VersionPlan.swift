import Foundation

/// 앱이 동시에 아는 세 버전. 현재는 번들, 최소는 정책, 최신은 릴리즈.
public struct VersionTrio: Equatable, Sendable {
    public var current: AppVersion
    public var minimum: AppVersion
    public var latest: AppVersion?

    public var isBelowMinimum: Bool { current < minimum }

    public init(current: AppVersion, minimum: AppVersion, latest: AppVersion? = nil) {
        self.current = current
        self.minimum = minimum
        self.latest = latest
    }

    public static func unrestricted(current: AppVersion) -> VersionTrio {
        VersionTrio(
            current: current,
            minimum: AppVersion(Defaults.unrestrictedMinimum),
            latest: nil
        )
    }
}

/// 세 버전으로 다음에 할 일을 정한다.
public enum UpdatePlan: Equatable, Sendable {
    case currentIsNewest
    case optional(AppRelease)
    case required(minimum: AppVersion, latest: AppRelease?, message: String)

    /// 최소 버전 미달이고 최신 zip이 있으면 그걸 받는다.
    public var shouldInstallLatest: Bool {
        if case .required(_, let latest, _) = self { return latest != nil }
        return false
    }

    public static func evaluate(
        current: AppVersion,
        minimum: AppVersion?,
        latest: AppRelease?,
        message: String
    ) -> UpdatePlan {
        let min = minimum ?? AppVersion(Defaults.unrestrictedMinimum)
        let msg = message.isEmpty ? Defaults.forcedUpdateMessage : message
        if current < min {
            return .required(minimum: min, latest: latest, message: msg)
        }
        if let latest, latest.version > current {
            return .optional(latest)
        }
        return .currentIsNewest
    }
}
