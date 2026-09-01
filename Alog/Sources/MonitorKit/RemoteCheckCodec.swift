import Foundation

/// 서버 CheckRequest/CheckRun JSON과 MonitorKit 모델 사이 변환 계약.
public enum RemoteCheckCodec {
    public static let supportedKinds: Set<ActionKind> = [
        .pageLoaded, .hasTitle, .bodyHasText, .scrollToBottom, .checkSelector, .checkText,
    ]

    public static func requestBody(
        target: Target,
        timeoutMs: Int,
        settleMs: Int,
        vantageName: String?
    ) throws -> Data {
        let actions: [[String: Any]] = target.actions.compactMap { spec in
            guard supportedKinds.contains(spec.kind) else { return nil }
            var item: [String: Any] = ["kind": spec.kind.rawValue]
            if !spec.selector.isEmpty { item["selector"] = spec.selector }
            if !spec.text.isEmpty { item["text"] = spec.text }
            if spec.kind == .scroll { item["pixels"] = spec.pixels }
            // 기본 ActionSpec.ms=500 은 대기 동작 전용. 그대로 보내면 서버가 항목마다 0.5s를 쉼.
            if spec.kind == .wait, spec.ms > 0 { item["ms"] = spec.ms }
            return item
        }
        var payload: [String: Any] = [
            "url": target.url,
            "timeoutMs": timeoutMs,
            "settleMs": settleMs,
            "targetName": target.name.isEmpty ? target.url : target.name,
            "actions": actions,
        ]
        if let vantageName, !vantageName.isEmpty {
            payload["vantage"] = vantageName
        }
        return try JSONSerialization.data(withJSONObject: payload)
    }

    public static func checkRun(from data: Data, fallbackTarget: Target) throws -> CheckRun {
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let obj else { throw RemoteCheckError.invalidResponse }
        let itemsJSON = obj["items"] as? [[String: Any]] ?? []
        let items: [ActionOutcome] = itemsJSON.map { item in
            let kindRaw = item["kind"] as? String ?? ""
            let kind = ActionKind(rawValue: kindRaw) ?? .pageLoaded
            return ActionOutcome(
                actionKind: kind,
                ok: item["ok"] as? Bool ?? false,
                detail: item["detail"] as? String ?? "",
                durationMs: item["durationMs"] as? Int ?? 0
            )
        }
        let url = obj["url"] as? String ?? fallbackTarget.url
        let name = obj["targetName"] as? String
            ?? (fallbackTarget.name.isEmpty ? fallbackTarget.url : fallbackTarget.name)
        return CheckRun(
            timestamp: parseTimestamp(obj["timestamp"] as? String) ?? Date(),
            targetName: name,
            url: url,
            vantageName: obj["vantageName"] as? String ?? "",
            ok: obj["ok"] as? Bool ?? items.allSatisfy(\.ok),
            items: items,
            durationMs: obj["durationMs"] as? Int ?? 0
        )
    }

    public static func parseTimestamp(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFrac.date(from: raw) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }
}

public enum RemoteCheckError: Error, Equatable {
    case invalidResponse
    case httpStatus(Int, String)
    case missingToken
    case invalidBaseURL
}
