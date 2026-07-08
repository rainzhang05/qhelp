import Foundation
@testable import ClipAICore

enum ProviderHTTPTests: TestCase {
    static let name = "ProviderHTTPTests"

    static func run() throws {
        try testRetryAfterParsing()
        try testBackoffDelay()
        try testOpenAIErrorParsing()
        try testNetworkErrorMapping()
        try testUserFacingMessages()
    }

    private static func testRetryAfterParsing() throws {
        try assertEqual(ProviderHTTP.parseRetryAfter("30"), 30)
        try assertEqual(ProviderHTTP.parseRetryAfter("0"), nil)
        try assertEqual(ProviderHTTP.parseRetryAfter("-1"), nil)
        try assertEqual(ProviderHTTP.parseRetryAfter("soon"), nil)
        try assertEqual(ProviderHTTP.parseRetryAfter(nil), nil)
    }

    private static func testBackoffDelay() throws {
        try assertEqual(
            ProviderHTTP.backoffDelay(for: 0, retryAfter: nil),
            2_000_000_000
        )
        try assertEqual(
            ProviderHTTP.backoffDelay(for: 2, retryAfter: nil),
            8_000_000_000
        )
        try assertEqual(
            ProviderHTTP.backoffDelay(for: 0, retryAfter: 5),
            5_000_000_000
        )
    }

    private static func testOpenAIErrorParsing() throws {
        let rateLimit = ProviderHTTP.parseOpenAIError(
            statusCode: 429,
            data: Data(),
            retryAfterHeader: "11"
        )
        guard case .rateLimited(let retryAfter) = rateLimit else {
            throw TestFailure.message("Expected rateLimited")
        }
        try assertEqual(retryAfter, 11)

        let errorJSON = Data("""
        {"error":{"message":"bad request"}}
        """.utf8)
        let apiError = ProviderHTTP.parseOpenAIError(
            statusCode: 400,
            data: errorJSON,
            retryAfterHeader: nil
        )
        guard case .apiError(let statusCode, let message) = apiError else {
            throw TestFailure.message("Expected apiError")
        }
        try assertEqual(statusCode, 400)
        try assertEqual(message, "bad request")
    }

    private static func testNetworkErrorMapping() throws {
        let timeout = ProviderHTTP.mapNetworkError(URLError(.timedOut))
        guard case .timeout = timeout as? ProviderError else {
            throw TestFailure.message("Expected timeout")
        }

        let unavailable = ProviderHTTP.mapNetworkError(URLError(.notConnectedToInternet))
        guard case .networkUnavailable = unavailable as? ProviderError else {
            throw TestFailure.message("Expected networkUnavailable")
        }

        let unreachable = ProviderHTTP.mapNetworkError(URLError(.cannotConnectToHost))
        guard case .serverUnreachable = unreachable as? ProviderError else {
            throw TestFailure.message("Expected serverUnreachable")
        }
    }

    private static func testUserFacingMessages() throws {
        let message = ProviderHTTP.userFacingMessage(for: ProviderError.timeout)
        try assertEqual(message, "Request timed out.")
    }
}
