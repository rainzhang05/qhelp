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
                throw mapNetworkError(error)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                return try parseResponse(data)
            }

            if httpResponse.statusCode == 429, attempt < maxRateLimitRetries {
                let retryAfter = parseRetryAfter(
                    httpResponse.value(forHTTPHeaderField: "Retry-After")
                )
                let delay = backoffDelay(for: attempt, retryAfter: retryAfter)
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
            return .rateLimited(retryAfter: parseRetryAfter(retryAfterHeader))
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return .apiError(statusCode: statusCode, message: message)
        }

        return .apiError(statusCode: statusCode, message: "Unknown error (HTTP \(statusCode))")
    }

    static func fetchData(_ request: URLRequest, session: URLSession) async throws -> Data {
        let (data, response) = try await fetchResponse(request, session: session)

        guard response.statusCode == 200 else {
            throw ProviderError.apiError(
                statusCode: response.statusCode,
                message: "Model metadata request failed (HTTP \(response.statusCode))"
            )
        }

        return data
    }

    static func fetchResponse(
        _ request: URLRequest,
        session: URLSession
    ) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        return (data, httpResponse)
    }

    static func parseRetryAfter(_ header: String?) -> Int? {
        guard let header, let seconds = Int(header), seconds > 0 else {
            return nil
        }
        return seconds
    }

    static func backoffDelay(for attempt: Int, retryAfter: Int?) -> UInt64 {
        if let retryAfter {
            return UInt64(retryAfter) * 1_000_000_000
        }
        return UInt64(pow(2.0, Double(attempt + 1))) * 1_000_000_000
    }

    static func mapNetworkError(_ error: Error) -> Error {
        if error is ProviderError || error is CancellationError {
            return error
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return ProviderError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                return ProviderError.networkUnavailable
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return ProviderError.serverUnreachable
            default:
                return ProviderError.networkError(urlError.localizedDescription)
            }
        }

        return error
    }

    static func userFacingMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
