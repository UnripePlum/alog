import Foundation

/// 페이지 안에서 수행할 점검 동작 종류.
public enum ActionKind: String, Codable, CaseIterable, Sendable, Hashable {
    // 일반(파라미터 불필요) — 페이지 종류와 무관하게 렌더링 건강도를 봄
    case hasTitle = "has_title"            // <title>이 비어있지 않은지
    case bodyHasText = "body_has_text"     // 실제 본문 텍스트가 렌더됐는지
    case scrollToBottom = "scroll_to_bottom" // 맨 아래까지 스크롤 가능한지
    case pageLoaded = "page_loaded"        // document.readyState == complete

    // 고급(파라미터 필요) — 특정 요소/텍스트 지정
    case checkSelector = "check_selector"  // 특정 요소가 렌더링됐는지
    case checkText = "check_text"          // 특정 텍스트가 본문에 있는지
    case click                             // 특정 요소 클릭
    case scroll                            // 지정 픽셀 스크롤
    case wait                              // 대기(동적 렌더 안정화)

    /// UI 표시용 한글 라벨.
    public var label: String {
        switch self {
        case .hasTitle: return "제목 있는지"
        case .bodyHasText: return "본문 있음"
        case .scrollToBottom: return "스크롤 끝까지"
        case .pageLoaded: return "로드 완료"
        case .checkSelector: return "요소 확인(고급)"
        case .checkText: return "텍스트 확인(고급)"
        case .click: return "클릭(고급)"
        case .scroll: return "픽셀 스크롤(고급)"
        case .wait: return "대기"
        }
    }

    /// 파라미터(셀렉터/텍스트/픽셀 등)가 필요한 고급 동작인지.
    public var needsParams: Bool {
        switch self {
        case .hasTitle, .bodyHasText, .scrollToBottom, .pageLoaded: return false
        case .checkSelector, .checkText, .click, .scroll, .wait: return true
        }
    }
}

/// 단일 점검 동작 명세. 파라미터는 종류별로 필요한 것만 채운다.
public struct ActionSpec: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var kind: ActionKind
    public var selector: String
    public var text: String
    public var pixels: Int
    public var ms: Int

    public init(
        id: UUID = UUID(),
        kind: ActionKind,
        selector: String = "",
        text: String = "",
        pixels: Int = 500,
        ms: Int = 500
    ) {
        self.id = id
        self.kind = kind
        self.selector = selector
        self.text = text
        self.pixels = pixels
        self.ms = ms
    }
}

/// 점검 대상 사이트 + 그 안에서 돌아가며 수행할 동작 목록.
public struct Target: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var url: String
    public var actions: [ActionSpec]
    /// false면 백그라운드 점검을 하지 않는다. 구 설정 파일에는 키가 없으면 true.
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        url: String,
        actions: [ActionSpec],
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.actions = actions
        self.enabled = enabled
    }

    enum CodingKeys: String, CodingKey {
        case id, name, url, actions, enabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        url = try c.decode(String.self, forKey: .url)
        actions = try c.decode([ActionSpec].self, forKey: .actions)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

/// 랜덤화된 점검 간격(초).
public struct ScheduleConfig: Codable, Sendable, Hashable {
    public var minSeconds: Double
    public var maxSeconds: Double

    public init(minSeconds: Double, maxSeconds: Double) {
        self.minSeconds = minSeconds
        self.maxSeconds = maxSeconds
    }

    /// 로그/설정에 쓰는 짧은 간격 문구. 60초 이상은 분으로.
    public var intervalLabel: String {
        let lo = min(minSeconds, maxSeconds)
        let hi = max(minSeconds, maxSeconds)
        if lo >= 60, hi >= 60 {
            let a = Int((lo / 60).rounded())
            let b = Int((hi / 60).rounded())
            if a == b { return "\(a)분마다" }
            return "\(a)~\(b)분마다"
        }
        return "\(Int(lo))~\(Int(hi))초마다"
    }
}

/// 다지역 점검용 관측점. 지정한 프록시(HTTP CONNECT)로 트래픽을 내보내
/// 그 지역/네트워크 egress에서 접속한 것처럼 사이트 도달성을 확인한다.
/// 프록시는 사용자가 소유/권한 있는 것을 등록한다(bring-your-own).
public struct Vantage: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String       // 예: "도쿄", "US-East"
    public var proxyHost: String
    public var proxyPort: Int

    public init(id: UUID = UUID(), name: String, proxyHost: String, proxyPort: Int) {
        self.id = id
        self.name = name
        self.proxyHost = proxyHost
        self.proxyPort = proxyPort
    }
}

/// 로컬 모드면 이 맥 WebKit, 꺼지면 서버 실행기.
/// URL이 비면 identity.checkAPIBaseURL을 쓴다.
public struct RemoteEngineConfig: Codable, Sendable, Hashable {
    public var localMode: Bool
    public var baseURL: String

    public init(localMode: Bool = false, baseURL: String = "") {
        self.localMode = localMode
        self.baseURL = baseURL
    }

    public var usesRemoteEngine: Bool { !localMode }

    enum CodingKeys: String, CodingKey {
        case localMode, baseURL, enabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try c.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        if let local = try c.decodeIfPresent(Bool.self, forKey: .localMode) {
            localMode = local
        } else if let enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) {
            localMode = !enabled
        } else {
            localMode = false
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(localMode, forKey: .localMode)
        try c.encode(baseURL, forKey: .baseURL)
    }
}

public struct AppConfig: Codable, Sendable, Hashable {
    public var targets: [Target]
    public var schedule: ScheduleConfig
    public var timeoutMs: Int
    public var settleMs: Int
    public var vantages: [Vantage]   // 로컬 브라우저 폴백일 때만 사용
    public var remoteEngine: RemoteEngineConfig

    public init(
        targets: [Target],
        schedule: ScheduleConfig,
        timeoutMs: Int,
        settleMs: Int,
        vantages: [Vantage] = [],
        remoteEngine: RemoteEngineConfig = RemoteEngineConfig()
    ) {
        self.targets = targets
        self.schedule = schedule
        self.timeoutMs = timeoutMs
        self.settleMs = settleMs
        self.vantages = vantages
        self.remoteEngine = remoteEngine
    }

    enum CodingKeys: String, CodingKey {
        case targets, schedule, timeoutMs, settleMs, vantages, remoteEngine
    }

    // 기존 설정 파일(vantages/remoteEngine 없음)과 하위 호환.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        targets = try c.decode([Target].self, forKey: .targets)
        schedule = try c.decode(ScheduleConfig.self, forKey: .schedule)
        timeoutMs = try c.decode(Int.self, forKey: .timeoutMs)
        settleMs = try c.decode(Int.self, forKey: .settleMs)
        vantages = try c.decodeIfPresent([Vantage].self, forKey: .vantages) ?? []
        remoteEngine = try c.decodeIfPresent(RemoteEngineConfig.self, forKey: .remoteEngine)
            ?? RemoteEngineConfig()
    }
}

/// 단일 동작 수행 결과.
public struct ActionResult: Sendable, Hashable {
    public var ok: Bool
    public var detail: String
    public init(ok: Bool, detail: String) {
        self.ok = ok
        self.detail = detail
    }
}

/// 테스트 1회 안의 개별 동작(항목) 결과.
public struct ActionOutcome: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var actionKind: ActionKind
    public var ok: Bool
    public var detail: String
    public var durationMs: Int

    public init(
        id: UUID = UUID(),
        actionKind: ActionKind,
        ok: Bool,
        detail: String,
        durationMs: Int
    ) {
        self.id = id
        self.actionKind = actionKind
        self.ok = ok
        self.detail = detail
        self.durationMs = durationMs
    }
}

/// 한 번의 테스트(페이지 1번 방문 + 설정된 모든 동작 점검) 결과.
/// 로그/화면에 한 항목으로 표시되고, 그 안에 각 동작 결과(items)가 들어간다.
public struct CheckRun: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var timestamp: Date
    public var targetName: String
    public var url: String
    public var vantageName: String  // 어느 관측점에서 점검했는지 (예: "직접(로컬)", "도쿄")
    public var ok: Bool             // 모든 항목이 정상이면 true
    public var items: [ActionOutcome]
    public var durationMs: Int      // 전체 소요

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        targetName: String,
        url: String,
        vantageName: String = "직접(로컬)",
        ok: Bool,
        items: [ActionOutcome],
        durationMs: Int
    ) {
        self.id = id
        self.timestamp = timestamp
        self.targetName = targetName
        self.url = url
        self.vantageName = vantageName
        self.ok = ok
        self.items = items
        self.durationMs = durationMs
    }
}
