import Foundation

/// 점검 결과 로거 계약.
public protocol ResultLogger: Sendable {
    func log(_ run: CheckRun)
}

/// JSON Lines 파일 로거. 디렉터리는 없으면 생성. 알림/복구는 non-goal — 로그만.
public final class JSONLLogger: ResultLogger, @unchecked Sendable {
    private let url: URL
    private let queue = DispatchQueue(label: "monitorkit.jsonllogger")
    private let iso = ISO8601DateFormatter()

    public init(url: URL) {
        self.url = url
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    public func log(_ run: CheckRun) {
        let items: [[String: Any]] = run.items.map { item in
            [
                "action": item.actionKind.rawValue,
                "status": item.ok ? "ok" : "fail",
                "detail": item.detail,
                "duration_ms": item.durationMs,
            ]
        }
        let record: [String: Any] = [
            "timestamp": iso.string(from: run.timestamp),
            "target": run.targetName,
            "url": run.url,
            "vantage": run.vantageName,
            "status": run.ok ? "ok" : "fail",
            "duration_ms": run.durationMs,
            "items": items,
        ]
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: record, options: [.sortedKeys]),
            let line = String(data: data, encoding: .utf8)
        else { return }

        queue.sync {
            let payload = Data((line + "\n").utf8)
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: payload)
            } else {
                try? payload.write(to: url)
            }
        }
    }

    /// 로그 파일 경로(표시용).
    public var fileURL: URL { url }
}
