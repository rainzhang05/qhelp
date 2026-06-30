import Foundation

/// Shared HTTP request execution with retries and error mapping.
enum ProviderHTTP {

    static let maxRateLimitRetries = 2
    static let timeoutInterval: TimeInterval = 120

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = timeoutInterval
        return URLSession(configuration: configuration)
    }

    static func performRequest(
        _ request: URLRequest,
        session: URLSession,
        parseResponse: (Data) throws -> String,
        parseError: (Int, Data, String?) -> ProviderError
    ) async throws -> String {
        var attempt = 0

        while true {
            try Task.checkCancellation()

            let data: Data
            let response: URLResponse

            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw AnthropicAPI.mapNetworkError(error)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                return try parseResponse(data)
            }

            if httpResponse.statusCode == 429, attempt < maxRateLimitRetries {
                let retryAfter = AnthropicAPI.parseRetryAfter(
                    httpResponse.value(forHTTPHeaderField: "Retry-After")
                )
                let delay = AnthropicAPI.backoffDelay(for: attempt, retryAfter: retryAfter)
                attempt += 1
                try await Task.sleep(nanoseconds: delay)
                continue
            }

            throw parseError(
                httpResponse.statusCode,
                data,
                httpResponse.value(forHTTPHeaderField: "Retry-After")
            )
        }
    }

    static func parseOpenAIError(statusCode: Int, data: Data, retryAfterHeader: String?) -> ProviderError {
        if statusCode == 429 {
            return .rateLimited(retryAfter: AnthropicAPI.parseRetryAfter(retryAfterHeader))
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return .apiError(statusCode: statusCode, message: message)
        }

        return .apiError(statusCode: statusCode, message: "Unknown error (HTTP \(statusCode))")
    }
}
