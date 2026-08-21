import Foundation

/// 대상별 라운드로빈 커서 (휘발성 상태 — 단일 소유자에서만 사용).
/// 매 사이클 다음 동작 인덱스를 돌려준다. 재시작하면 0부터.
public final class RotationCursor {
    private var cursor: [UUID: Int] = [:]

    public init() {}

    /// 대상 id에 대한 다음 인덱스를 반환하고 커서를 1 증가.
    public func next(_ id: UUID) -> Int {
        let i = cursor[id, default: 0]
        cursor[id] = i + 1
        return i
    }

    public func reset() {
        cursor.removeAll()
    }
}
