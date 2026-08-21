import Foundation

/// 대상을 한 번 방문해 설정된 모든 동작을 점검하고, 묶음 결과(CheckRun)를 만드는 계약.
/// 구현체: WebPageChecker(실 브라우저), 테스트용 스텁 등.
public protocol Checker: Sendable {
    /// vantage가 nil이면 로컬에서 직접, 아니면 해당 프록시를 통해 점검.
    func runCheck(target: Target, vantage: Vantage?) async -> CheckRun
}
