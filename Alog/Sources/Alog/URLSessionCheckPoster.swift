import Foundation
import MonitorKit

struct URLSessionCheckPoster: CheckPoster {
    var session: URLSession = .shared

    func post(url: URL, headers: [String: String], body: Data) async throws -> (status: Int, data: Data) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 90
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (status, data)
    }
}
