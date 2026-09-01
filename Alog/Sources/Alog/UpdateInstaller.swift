import Foundation
import AppKit
import MonitorKit

/// zip을 풀어 실행 중인 .app을 교체한 뒤 다시 연다.
struct UpdateInstaller {
    var http: any HTTPClient
    var identity: AppIdentity
    var fileManager: FileManager = .default

    func stage(_ release: AppRelease) async throws -> URL {
        let work = fileManager.temporaryDirectory
            .appendingPathComponent("AlogUpdate-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: work, withIntermediateDirectories: true)
        let zip = work.appendingPathComponent("update.zip")
        try await http.download(from: release.downloadURL, to: zip)
        let unpacked = work.appendingPathComponent("unpacked", isDirectory: true)
        try fileManager.createDirectory(at: unpacked, withIntermediateDirectories: true)
        try unzip(zip, to: unpacked)
        guard let app = findApp(in: unpacked) else { throw UpdateError.noZipAsset }
        return app
    }

    func replaceRunningApp(with staged: URL) throws {
        let current = Bundle.main.bundleURL
        let dest = current
        let scriptURL = fileManager.temporaryDirectory
            .appendingPathComponent("alog-relaunch-\(UUID().uuidString).sh")
        let pid = ProcessInfo.processInfo.processIdentifier
        let body = """
        #!/bin/bash
        set -euo pipefail
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        rm -rf \(shQuote(dest.path))
        mv \(shQuote(staged.path)) \(shQuote(dest.path))
        open \(shQuote(dest.path))
        rm -f "$0"
        """
        try body.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [scriptURL.path]
        try proc.run()
        NSApplication.shared.terminate(nil)
    }

    func findApp(in directory: URL) -> URL? {
        let expected = directory.appendingPathComponent("\(identity.bundleFileName).app")
        if fileManager.fileExists(atPath: expected.path) { return expected }
        let kids = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return kids.first { $0.pathExtension == "app" }
    }

    private func unzip(_ zip: URL, to dest: URL) throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        proc.arguments = ["-x", "-k", zip.path, dest.path]
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { throw UpdateError.badResponse }
    }

    private func shQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
