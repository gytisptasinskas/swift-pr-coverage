import Foundation
import Testing
@testable import GitHubClient

/// Replays canned responses and records the requests it received.
private final class FakeTransport: HTTPTransport, @unchecked Sendable {
    struct Reply {
        var status: Int
        var json: String
    }

    private let lock = NSLock()
    private var replies: [Reply]
    private(set) var requests: [URLRequest] = []

    init(_ replies: [Reply]) {
        self.replies = replies
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let reply = lock.withLock {
            requests.append(request)
            return replies.removeFirst()
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!
        return (Data(reply.json.utf8), response)
    }
}

private func comment(_ id: Int, _ body: String) -> String {
    #"{"id":\#(id),"body":"\#(body)","html_url":"https://github.com/o/r/pull/7#issuecomment-\#(id)"}"#
}

private func page(_ comments: [String]) -> String {
    "[" + comments.joined(separator: ",") + "]"
}

struct GitHubClientTests {
    private let marker = "<!-- swift-pr-coverage -->"

    @Test func updatesExistingComment() async throws {
        let transport = FakeTransport([
            .init(status: 200, json: page([comment(1, "hello"), comment(2, "<!-- swift-pr-coverage -->\\nold")])),
            .init(status: 200, json: comment(2, "new")),
        ])
        let client = GitHubClient(token: "t", transport: transport)

        let result = try await client.upsertComment(repository: "o/r", pullRequest: 7, marker: marker, body: "new")

        #expect(result == .updated(IssueComment(id: 2, body: "new", htmlURL: "https://github.com/o/r/pull/7#issuecomment-2")))
        let patch = try #require(transport.requests.last)
        #expect(patch.httpMethod == "PATCH")
        #expect(patch.url?.absoluteString == "https://api.github.com/repos/o/r/issues/comments/2")
        #expect(try JSONDecoder().decode([String: String].self, from: patch.httpBody ?? Data()) == ["body": "new"])
    }

    @Test func createsCommentWhenNoneHasMarker() async throws {
        let transport = FakeTransport([
            .init(status: 200, json: page([comment(1, "hello")])),
            .init(status: 201, json: comment(3, "new")),
        ])
        let client = GitHubClient(token: "t", transport: transport)

        let result = try await client.upsertComment(repository: "o/r", pullRequest: 7, marker: marker, body: "new")

        guard case .created(let created) = result else {
            Issue.record("expected created, got \(result)")
            return
        }
        #expect(created.id == 3)
        let post = try #require(transport.requests.last)
        #expect(post.httpMethod == "POST")
        #expect(post.url?.absoluteString == "https://api.github.com/repos/o/r/issues/7/comments")
    }

    @Test func skipsCreateWhenNotAllowed() async throws {
        let transport = FakeTransport([.init(status: 200, json: "[]")])
        let client = GitHubClient(token: "t", transport: transport)

        let result = try await client.upsertComment(
            repository: "o/r", pullRequest: 7, marker: marker, body: "new", createIfMissing: false
        )

        #expect(result == .skipped)
        #expect(transport.requests.count == 1)
    }

    @Test func pagesThroughComments() async throws {
        let fullPage = page((1...100).map { comment($0, "x") })
        let transport = FakeTransport([
            .init(status: 200, json: fullPage),
            .init(status: 200, json: page([comment(101, "<!-- swift-pr-coverage -->")])),
        ])
        let client = GitHubClient(token: "t", transport: transport)

        let found = try await client.findComment(repository: "o/r", pullRequest: 7, marker: marker)

        #expect(found?.id == 101)
        #expect(transport.requests.map { $0.url?.query } == ["per_page=100&page=1", "per_page=100&page=2"])
    }

    @Test func sendsAuthHeaders() async throws {
        let transport = FakeTransport([.init(status: 200, json: "[]")])
        let client = GitHubClient(token: "secret", transport: transport)

        _ = try await client.findComment(repository: "o/r", pullRequest: 7, marker: marker)

        let request = try #require(transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
    }

    @Test func usesEnterpriseAPIURL() async throws {
        let transport = FakeTransport([.init(status: 200, json: "[]")])
        let client = GitHubClient(token: "t", apiURL: URL(string: "https://ghe.example.com/api/v3")!, transport: transport)

        _ = try await client.findComment(repository: "o/r", pullRequest: 7, marker: marker)

        #expect(transport.requests.first?.url?.absoluteString == "https://ghe.example.com/api/v3/repos/o/r/issues/7/comments?per_page=100&page=1")
    }

    @Test func readOnlyTokenIsPermissionDenied() async throws {
        let transport = FakeTransport([
            .init(status: 200, json: "[]"),
            .init(status: 403, json: #"{"message":"Resource not accessible by integration"}"#),
        ])
        let client = GitHubClient(token: "t", transport: transport)

        let error = try await #require(throws: GitHubError.self) {
            try await client.upsertComment(repository: "o/r", pullRequest: 7, marker: marker, body: "new")
        }

        #expect(error.isPermissionDenied)
        #expect(error.description == "GitHub API returned 403: Resource not accessible by integration")
    }
}
