import Foundation

/// 실행기 토큰은 설정 JSON이 아니라 파일/환경에서 읽는다.
public enum TokenResolver {
    public static let envTokenKey = "ALOGN_API_TOKEN"
    public static let envTokenPathKey = "ALOGN_TOKEN_PATH"
    public static let fileName = "api-token"

    public static func resolve(
        supportDirectory: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> String? {
        if let env = environment[envTokenKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }
        if let path = environment[envTokenPathKey], !path.isEmpty,
           let token = readToken(at: URL(fileURLWithPath: path), fileManager: fileManager) {
            return token
        }
        let local = supportDirectory.appendingPathComponent(fileName)
        return readToken(at: local, fileManager: fileManager)
    }

    public static func readToken(at url: URL, fileManager: FileManager = .default) -> String? {
        guard fileManager.fileExists(atPath: url.path),
              let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }
}
