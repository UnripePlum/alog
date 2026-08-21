import Foundation
import MonitorKit

struct URLSessionHTTPClient: HTTPClient {
    var session: URLSession = .shared

    func data(from url: URL, headers: [String: String]) async throws -> Data {
        var request = URLRequest(url: url)
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UpdateError.badResponse
        }
        return data
    }

    func download(from url: URL, to destination: URL) async throws {
        let (tmp, response) = try await session.download(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UpdateError.badResponse
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tmp, to: destination)
    }
}
