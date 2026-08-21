import Foundation

/// AppConfig 를 JSON 파일로 로드/저장. 진실의 원천은 이 파일.
public struct ConfigStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// 표준 위치: ~/Library/Application Support/<identity.supportDirectoryName>/config.json
    public static func defaultStore(
        fileManager: FileManager = .default,
        identity: AppIdentity = .current
    ) -> ConfigStore {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = base.appendingPathComponent(identity.supportDirectoryName, isDirectory: true)
        let store = ConfigStore(url: dir.appendingPathComponent("config.json"))
        migrateLegacyConfigIfNeeded(
            newConfigURL: store.url,
            fileManager: fileManager,
            identity: identity
        )
        return store
    }

    /// 이전 앱 이름 폴더에만 설정이 있으면 새 폴더로 복사한다. 덮어쓰지 않음.
    public static func migrateLegacyConfigIfNeeded(
        newConfigURL: URL,
        fileManager: FileManager,
        identity: AppIdentity
    ) {
        guard !fileManager.fileExists(atPath: newConfigURL.path) else { return }
        let newDir = newConfigURL.deletingLastPathComponent()
        let parent = newDir.deletingLastPathComponent()
        for name in identity.legacySupportDirectoryNames {
            let oldDir = parent.appendingPathComponent(name, isDirectory: true)
            let oldConfig = oldDir.appendingPathComponent(newConfigURL.lastPathComponent)
            guard fileManager.fileExists(atPath: oldConfig.path) else { continue }
            try? fileManager.createDirectory(at: newDir, withIntermediateDirectories: true)
            try? fileManager.copyItem(at: oldConfig, to: newConfigURL)
            let oldLog = oldDir.appendingPathComponent("monitor.log")
            let newLog = newDir.appendingPathComponent("monitor.log")
            if fileManager.fileExists(atPath: oldLog.path),
               !fileManager.fileExists(atPath: newLog.path) {
                try? fileManager.copyItem(at: oldLog, to: newLog)
            }
            break
        }
    }

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
