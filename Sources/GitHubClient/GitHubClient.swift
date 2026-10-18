import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}

public struct IssueComment: Sendable, Equatable, Decodable {
    public var id: Int
    public var body: String?
    public var htmlURL: String

    public init(id: Int, body: String?, htmlURL: String) {
        self.id = id
        self.body = body
        self.htmlURL = htmlURL
    }

    private enum CodingKeys: String, CodingKey {
        case id, body
        case htmlURL = "html_url"
    }
}

public struct GitHubError: Error, CustomStringConvertible {
    public var status: Int
    public var message: String

    /// 401/403/404 on a write: typically a read-only token on a fork PR.
    public var isPermissionDenied: Bool {
        [401, 403, 404].contains(status)
    }

    public var description: String {
        "GitHub API returned \(status): \(message)"
    }
}

/// Finds, creates and updates the tool's sticky issue comment on a pull request.
public struct GitHubClient: Sendable {
    public enum UpsertResult: Sendable, Equatable {
        case created(IssueComment)
        case updated(IssueComment)
        /// No existing comment and `createIfMissing` was false.
        case skipped
    }

    private let token: String
    private let apiURL: URL
    private let transport: any HTTPTransport

    public init(token: String, apiURL: URL = URL(string: "https://api.github.com")!, transport: any HTTPTransport = URLSessionTransport()) {
        self.token = token
        self.apiURL = apiURL
        self.transport = transport
    }

    /// Updates the first comment containing `marker`, or creates one.
    public func upsertComment(
        repository: String,
        pullRequest: Int,
        marker: String,
        body: String,
        createIfMissing: Bool = true
    ) async throws -> UpsertResult {
        if let existing = try await findComment(repository: repository, pullRequest: pullRequest, marker: marker) {
            return .updated(try await updateComment(repository: repository, id: existing.id, body: body))
        }
        guard createIfMissing else { return .skipped }
        return .created(try await createComment(repository: repository, pullRequest: pullRequest, body: body))
    }

    public func findComment(repository: String, pullRequest: Int, marker: String) async throws -> IssueComment? {
        var page = 1
        while true {
            let comments: [IssueComment] = try await request(
                "GET",
                "repos/\(repository)/issues/\(pullRequest)/comments",
                query: [URLQueryItem(name: "per_page", value: "100"), URLQueryItem(name: "page", value: "\(page)")]
            )
            if let match = comments.first(where: { $0.body?.contains(marker) == true }) {
                return match
            }
            if comments.count < 100 {
                return nil
            }
            page += 1
        }
    }

    public func createComment(repository: String, pullRequest: Int, body: String) async throws -> IssueComment {
        try await request("POST", "repos/\(repository)/issues/\(pullRequest)/comments", body: ["body": body])
    }

    public func updateComment(repository: String, id: Int, body: String) async throws -> IssueComment {
        try await request("PATCH", "repos/\(repository)/issues/comments/\(id)", body: ["body": body])
    }

    private func request<Response: Decodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: [String: String]? = nil
    ) async throws -> Response {
        var components = URLComponents(url: apiURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query
        }
        var request = URLRequest(url: components.url!, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("swift-pr-coverage", forHTTPHeaderField: "User-Agent")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.message
                ?? String(decoding: data, as: UTF8.self)
            throw GitHubError(status: response.statusCode, message: message)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private struct ErrorBody: Decodable {
        let message: String
    }
}
