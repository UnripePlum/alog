import Foundation

/// AppConfig 를 JSON 파일로 로드/저장. 진실의 원천은 이 파일.
public struct ConfigStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// 표준 위치: ~/Library/Application Support/SiteMonitor/config.json
    public static func defaultStore(
        fileManager: FileManager = .default
    ) -> ConfigStore {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = base.appendingPathComponent("SiteMonitor", isDirectory: true)
        return ConfigStore(url: dir.appendingPathComponent("config.json"))
    }

    /// 기본 로그 파일 경로 (설정 디렉터리 하위).
    public var logURL: URL {
        url.deletingLastPathComponent().appendingPathComponent("monitor.log")
    }

    public func load() -> AppConfig? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(AppConfig.self, from: data)
    }

    public func loadOrStarter() -> AppConfig {
        load() ?? Defaults.starterConfig()
    }

    @discardableResult
    public func save(_ config: AppConfig) -> Bool {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
