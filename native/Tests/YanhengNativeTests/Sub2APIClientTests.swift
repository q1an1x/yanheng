import XCTest
@testable import YanhengNative

final class Sub2APIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchSnapshotUsesAdminAPIContract() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "admin-secret")
            let path = request.url!.path
            if path == "/api/v1/admin/accounts" {
                return Self.response(request, body: """
                {"code":0,"data":{"items":[
                  {"id":1,"name":"codex-a","platform":"openai","status":"active","schedulable":true},
                  {"id":2,"name":"claude-a","platform":"anthropic","status":"active","schedulable":true}
                ],"total":2}}
                """)
            }
            if path == "/api/v1/admin/dashboard/stats" {
                return Self.response(request, body: """
                {"code":0,"data":{"today_requests":12,"today_input_tokens":1000,"today_output_tokens":500,
                "today_cache_creation_tokens":200,"today_cache_read_tokens":300,"today_tokens":2000,
                "today_cost":2.5,"total_tokens":9000,"rpm":4,"tpm":800}}
                """)
            }
            if path.contains("/usage") {
                XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "passive")
                return Self.response(request, body: """
                {"code":0,"data":{"five_hour":{"utilization":20,"resets_at":null},
                "seven_day":{"utilization":40,"resets_at":null}}}
                """)
            }
            throw URLError(.badURL)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let client = Sub2APIClient(session: URLSession(configuration: configuration))
        var config = YanhengConfig()
        config.baseURL = "https://sub2api.example"
        config.adminAPIKey = "admin-secret"
        config.minimumAvailableAccounts = 1

        let snapshot = try await client.fetchSnapshot(config: config)
        XCTAssertEqual(snapshot.availableAccounts, 2)
        XCTAssertEqual(snapshot.fiveHourRemaining, 80)
        XCTAssertEqual(snapshot.sevenDayRemaining, 60)
        XCTAssertEqual(snapshot.todayTokens, 2000)
        XCTAssertTrue(snapshot.platformSummary.contains("openai 1"))
        XCTAssertTrue(snapshot.platformSummary.contains("anthropic 1"))
    }

    private static func response(_ request: URLRequest, body: String) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
            Data(body.utf8)
        )
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
