import Foundation

/// 점검 API POST 계약. 앱은 URLSession, 테스트는 고정 응답.
public protocol CheckPoster: Sendable {
    func post(url: URL, headers: [String: String], body: Data) async throws -> (status: Int, data: Data)
}
