import Foundation

/// 폴백 기본값을 한 곳에 모은다 (분기 리터럴 금지 원칙).
/// 대상-특정 값(URL 등)은 절대 여기 두지 않는다.
public enum Defaults {
    public static let minSeconds: Double = 30
    public static let maxSeconds: Double = 90
    public static let timeoutMs: Int = 30_000
    public static let settleMs: Int = 1_200
    public static let policyFile = "update-policy.json"
    public static let policyRef = "HEAD"
    public static let githubHost = "github.com"
    public static let unrestrictedMinimum = "0.0.0.0"
    public static let forcedUpdateMessage = "이 버전은 더 이상 사용할 수 없습니다. 업데이트하세요."
    public static let apiTokenFileName = TokenResolver.fileName

    /// 새 사이트에 붙는 기본 점검 동작. 파라미터 없이 렌더링 건강도를 본다.
    public static func starterActions() -> [ActionSpec] {
        [
            ActionSpec(kind: .pageLoaded),
            ActionSpec(kind: .hasTitle),
            ActionSpec(kind: .bodyHasText),
            ActionSpec(kind: .scrollToBottom),
        ]
    }

    /// 앱 최초 실행 설정. 대상은 비움 — 사용자가 자기 사이트를 추가한다.
    public static func starterConfig() -> AppConfig {
        AppConfig(
            targets: [],
            schedule: ScheduleConfig(minSeconds: minSeconds, maxSeconds: maxSeconds),
            timeoutMs: timeoutMs,
            settleMs: settleMs
        )
    }
}
