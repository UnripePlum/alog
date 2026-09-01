import Foundation

/// 서버 실행기에 점검 1회를 맡긴다. 브라우저는 띄우지 않는다.
public struct RemoteChecker: Checker, Sendable {
    public var baseURL: URL
    public var token: String
    public var timeoutMs: Int
    public var settleMs: Int
    public var poster: any CheckPoster

    public init(
        baseURL: URL,
        token: String,
        timeoutMs: Int,
        settleMs: Int,
        poster: any CheckPoster
    ) {
        self.baseURL = baseURL
        self.token = token
        self.timeoutMs = timeoutMs
        self.settleMs = settleMs
        self.poster = poster
    }

    public func runCheck(target: Target, vantage: Vantage?) async -> CheckRun {
        let start = Date()
        do {
            let body = try RemoteCheckCodec.requestBody(
                target: target,
                timeoutMs: timeoutMs,
                settleMs: settleMs,
                vantageName: vantage?.name
            )
            let url = Self.checksURL(from: baseURL)
            let (status, data) = try await poster.post(
                url: url,
                headers: [
                    "Authorization": "Bearer \(token)",
                    "Content-Type": "application/json",
                ],
                body: body
            )
            if status == 401 {
                return failed(target, start, "실행기 토큰이 거부되었습니다", "unauthorized")
            }
            if !(200...299).contains(status) {
                let detail = String(data: data, encoding: .utf8) ?? "HTTP \(status)"
                return failed(target, start, detail, "http_\(status)")
            }
            return try RemoteCheckCodec.checkRun(from: data, fallbackTarget: target)
        } catch {
            return failed(target, start, error.localizedDescription, "transport")
        }
    }

    public static func checksURL(from baseURL: URL) -> URL {
        let trimmed = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: trimmed + "/v1/checks") ?? baseURL.appendingPathComponent("v1/checks")
    }

    public static func resolvedBaseURL(config: RemoteEngineConfig, identity: AppIdentity) -> URL? {
        let raw = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let chosen = raw.isEmpty ? identity.checkAPIBaseURL : raw
        return URL(string: chosen)
    }

    private func failed(_ target: Target, _ start: Date, _ detail: String, _ kind: String) -> CheckRun {
        let items = target.actions.map {
            ActionOutcome(actionKind: $0.kind, ok: false, detail: detail, durationMs: 0)
        }
        return CheckRun(
            timestamp: Date(),
            targetName: target.name.isEmpty ? target.url : target.name,
            url: target.url,
            vantageName: kind,
            ok: false,
            items: items.isEmpty
                ? [ActionOutcome(actionKind: .pageLoaded, ok: false, detail: detail, durationMs: 0)]
                : items,
            durationMs: Int(Date().timeIntervalSince(start) * 1000)
        )
    }
}
