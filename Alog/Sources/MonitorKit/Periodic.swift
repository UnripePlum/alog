import Foundation

/// 기다리는 방법의 계약. 테스트는 구현체를 바꿔 실제 시간을 쓰지 않는다.
public protocol Sleeper: Sendable {
    /// 취소되면 던진다.
    func sleep(seconds: Double) async throws
}

/// 실제 시계. 맥이 잠든 시간도 흐른 것으로 센다 (깨어나면 밀린 확인을 바로 한다).
public struct ContinuousSleeper: Sleeper {
    public init() {}

    public func sleep(seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds), clock: .continuous)
    }
}

public enum Periodic {
    /// `interval` 초를 기다린 뒤 `body` 를 부르기를 반복한다. 첫 호출도 기다린 뒤다.
    /// Task 가 취소되거나 sleeper 가 던지면 끝난다. `interval` 이 0 이하면 아무것도 하지 않는다.
    public static func run(
        every interval: Double,
        sleeper: any Sleeper = ContinuousSleeper(),
        _ body: () async -> Void
    ) async {
        guard interval > 0 else { return }
        while !Task.isCancelled {
            do { try await sleeper.sleep(seconds: interval) } catch { return }
            if Task.isCancelled { return }
            await body()
        }
    }
}
