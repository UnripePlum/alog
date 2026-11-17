import Foundation

/// 켜져 있는 동안 새 버전을 다시 확인하는 간격을 정한다.
public enum UpdateSchedule {
    /// 초 단위 간격을 바꾸는 환경변수. 검증·운영에서 주입한다.
    public static let intervalEnvKey = "ALOG_UPDATE_CHECK_INTERVAL_SECONDS"

    /// 환경변수가 양수면 그 값, 없거나 잘못됐으면 `Defaults.updateCheckIntervalSeconds`.
    public static func interval(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Double {
        if let raw = environment[intervalEnvKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           let value = Double(raw), value > 0, value.isFinite {
            return value
        }
        return Defaults.updateCheckIntervalSeconds
    }
}
