import Foundation

/// `0.4.0.0` / `v0.4.0.0` 형태. 비교는 왼쪽부터 숫자 단위.
public struct AppVersion: Comparable, Sendable, Hashable {
    public let parts: [Int]

    public init(_ raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.first == "v" || s.first == "V" { s.removeFirst() }
        parts = s.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    }

    public var string: String {
        parts.map(String.init).joined(separator: ".")
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let n = max(lhs.parts.count, rhs.parts.count)
        for i in 0..<n {
            let a = i < lhs.parts.count ? lhs.parts[i] : 0
            let b = i < rhs.parts.count ? rhs.parts[i] : 0
            if a != b { return false }
        }
        return true
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let n = max(lhs.parts.count, rhs.parts.count)
        for i in 0..<n {
            let a = i < lhs.parts.count ? lhs.parts[i] : 0
            let b = i < rhs.parts.count ? rhs.parts[i] : 0
            if a != b { return a < b }
        }
        return false
    }

    public func hash(into hasher: inout Hasher) {
        let n = max(parts.count, 4)
        for i in 0..<n {
            hasher.combine(i < parts.count ? parts[i] : 0)
        }
    }
}

public enum RunningVersion {
    public static func fromBundle(_ bundle: Bundle) -> AppVersion {
        let raw = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "0"
        return AppVersion(raw)
    }
}
