import Foundation

/// 실행 중인 .app 을 제자리에서 교체해도 되는 위치인지 판정한다.
public enum InstallLocation {
    /// 교체할 수 없으면 던진다. 앱을 종료하기 **전에** 불러야 한다.
    /// - translocated: 격리된 채 읽기 전용 임시 경로에서 실행 중.
    /// - locationNotWritable: 상위 폴더에 쓸 권한이 없음 (일반 사용자 계정의 /Applications 등).
    public static func validate(
        bundleURL: URL,
        isWritable: (String) -> Bool = { FileManager.default.isWritableFile(atPath: $0) }
    ) throws {
        if bundleURL.path.contains(Defaults.translocationPathMarker) {
            throw UpdateError.translocated
        }
        let parent = bundleURL.deletingLastPathComponent().path
        guard isWritable(parent) else {
            throw UpdateError.locationNotWritable(parent)
        }
    }
}
