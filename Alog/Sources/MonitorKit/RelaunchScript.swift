import Foundation

/// 앱이 끝난 뒤 번들을 바꾸고 다시 여는 셸 스크립트 본문.
public enum RelaunchScript {
    /// 기존 번들은 지우지 않고 `backup` 으로 옮겨 둔다. 새 번들을 못 넣으면 되돌리므로
    /// 어느 경우든 `destination` 에 실행 가능한 앱이 남고, 마지막에 그것을 연다.
    public static func body(pid: Int32, staged: String, destination: String, backup: String) -> String {
        """
        #!/bin/bash
        set -u
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        if mv \(quote(destination)) \(quote(backup)); then
          if mv \(quote(staged)) \(quote(destination)); then
            rm -rf \(quote(backup))
          else
            mv \(quote(backup)) \(quote(destination))
          fi
        fi
        open \(quote(destination))
        rm -f "$0"
        """
    }

    public static func quote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
