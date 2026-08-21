import Foundation

/// 폴백 기본값을 한 곳에 모은다 (분기 리터럴 금지 원칙).
/// 대상-특정 값(URL 등)은 절대 여기 두지 않는다.
public enum Defaults {
    public static let minSeconds: Double = 300
    public static let maxSeconds: Double = 900
    public static let timeoutMs: Int = 30_000
    public static let settleMs: Int = 1_200

    /// 앱 최초 실행 시 보여줄 예시 설정.
    public static func starterConfig() -> AppConfig {
        AppConfig(
            targets: [
                Target(
                    name: "example",
                    url: "https://example.com/",
                    actions: [
                        ActionSpec(kind: .pageLoaded),
                        ActionSpec(kind: .hasTitle),
                        ActionSpec(kind: .bodyHasText),
                        ActionSpec(kind: .scrollToBottom),
                    ]
                )
            ],
            schedule: ScheduleConfig(minSeconds: minSeconds, maxSeconds: maxSeconds),
            timeoutMs: timeoutMs,
            settleMs: settleMs
        )
    }
}
