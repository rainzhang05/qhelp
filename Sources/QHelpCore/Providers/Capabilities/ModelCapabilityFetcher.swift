import Foundation

/// Fetches model capability metadata from provider Models APIs.
public enum ModelCapabilityFetcher {

    public static func fetch(
        kind: ProviderKind,
        modelIdentifier: String,
        apiKey: String,
        session: URLSession? = nil
    ) async -> ModelParameterProfile {
        let session = session ?? ProviderHTTP.makeSession()

        switch kind {
        case .anthropic:
            return await fetchAnthropic(
                modelIdentifier: modelIdentifier,
                apiKey: apiKey,
                session: session
            )
        case .gemini:
            return await fetchStandard(
                kind: kind,
                modelIdentifier: ProviderCatalog.normalizeGeminiModelIdentifier(modelIdentifier),
                apiKey: apiKey,
                session: session
            )
        case .openai, .grok, .kimi, .deepseek, .qwen, .glm:
            return await fetchStandard(
                kind: kind,
                modelIdentifier: modelIdentifier,
                apiKey: apiKey,
                session: session
            )
        }
    }

    public static func parseResponse(kind: ProviderKind, data: Data) -> ModelParameterProfile {
        switch kind {
        case .anthropic:
            return ModelCapabilityParser.parseAnthropic(data)
        case .gemini:
            return ModelCapabilityParser.parseGemini(data)
        case .openai, .grok, .kimi, .deepseek, .qwen, .glm:
            return ModelCapabilityParser.parseOpenAICompatible(data)
        }
    }

    public static func parseAnthropicList(
        data: Data,
        modelIdentifier: String
    ) -> ModelParameterProfile {
        ModelCapabilityParser.parseAnthropicModelList(data, modelIdentifier: modelIdentifier)
    }

    // MARK: - Anthropic

    private static func fetchAnthropic(
        modelIdentifier: String,
        apiKey: String,
        session: URLSession
    ) async -> ModelParameterProfile {
        if let retrieveURL = ProviderCatalog.anthropicModelURL(modelIdentifier: modelIdentifier) {
            var retrieveRequest = URLRequest(url: retrieveURL)
            configureAnthropicRequest(&retrieveRequest, apiKey: apiKey)

            do {
                let (data, response) = try await ProviderHTTP.fetchResponse(
                    retrieveRequest,
                    session: session
                )

                switch response.statusCode {
                case 200:
                    let profile = ModelCapabilityParser.parseAnthropic(data)
                    if isUseful(profile) {
                        return profile
                    }
                    print(
                        "Note: Model '\(modelIdentifier)' returned no capability metadata; trying model list..."
                    )
                case 404:
                    break
                default:
                    reportHTTPFailure(modelIdentifier: modelIdentifier, statusCode: response.statusCode, data: data)
                    return .empty
                }
            } catch {
                reportNetworkFailure(modelIdentifier: modelIdentifier, error: error)
                return .empty
            }
        }

        return await fetchAnthropicFromList(
            modelIdentifier: modelIdentifier,
            apiKey: apiKey,
            session: session
        )
    }

    private static func fetchAnthropicFromList(
        modelIdentifier: String,
        apiKey: String,
        session: URLSession
    ) async -> ModelParameterProfile {
        var after: String?

        while true {
            guard let listURL = ProviderCatalog.anthropicModelsListURL(after: after) else {
                break
            }

            var listRequest = URLRequest(url: listURL)
            configureAnthropicRequest(&listRequest, apiKey: apiKey)

            do {
                let (data, response) = try await ProviderHTTP.fetchResponse(listRequest, session: session)

                guard response.statusCode == 200 else {
                    reportHTTPFailure(
                        modelIdentifier: modelIdentifier,
                        statusCode: response.statusCode,
                        data: data
                    )
                    return .empty
                }

                let profile = ModelCapabilityParser.parseAnthropicModelList(
                    data,
                    modelIdentifier: modelIdentifier
                )
                if isUseful(profile) {
                    return profile
                }

                let pagination = ModelCapabilityParser.parseAnthropicListPagination(data)
                if pagination.hasMore, let lastID = pagination.lastID {
                    after = lastID
                    continue
                }

                break
            } catch {
                reportNetworkFailure(modelIdentifier: modelIdentifier, error: error)
                return .empty
            }
        }

        print(
            "Note: Could not load model options for '\(modelIdentifier)' (model not found). Continuing without prompts."
        )
        return .empty
    }

    // MARK: - Other providers

    private static func fetchStandard(
        kind: ProviderKind,
        modelIdentifier: String,
        apiKey: String,
        session: URLSession
    ) async -> ModelParameterProfile {
        guard let request = makeRequest(
            kind: kind,
            modelIdentifier: modelIdentifier,
            apiKey: apiKey
        ) else {
            return .empty
        }

        do {
            let data = try await ProviderHTTP.fetchData(request, session: session)
            return parseResponse(kind: kind, data: data)
        } catch let error as ProviderError {
            if case .apiError(let statusCode, _) = error {
                reportHTTPFailure(
                    modelIdentifier: modelIdentifier,
                    statusCode: statusCode,
                    data: Data()
                )
            } else {
                reportNetworkFailure(modelIdentifier: modelIdentifier, error: error)
            }
            return .empty
        } catch {
            reportNetworkFailure(modelIdentifier: modelIdentifier, error: error)
            return .empty
        }
    }

    private static func makeRequest(
        kind: ProviderKind,
        modelIdentifier: String,
        apiKey: String
    ) -> URLRequest? {
        let url: URL?
        switch kind {
        case .anthropic:
            url = ProviderCatalog.anthropicModelURL(modelIdentifier: modelIdentifier)
        case .gemini:
            url = ProviderCatalog.geminiModelURL(modelIdentifier: modelIdentifier, apiKey: apiKey)
        case .openai, .grok, .kimi, .deepseek, .qwen, .glm:
            url = ProviderCatalog.openAIModelURL(kind: kind, modelIdentifier: modelIdentifier)
        }

        guard let url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = ProviderHTTP.timeoutInterval

        switch kind {
        case .anthropic:
            configureAnthropicRequest(&request, apiKey: apiKey)
        case .gemini:
            break
        case .openai, .grok, .kimi, .deepseek, .qwen, .glm:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private static func configureAnthropicRequest(_ request: inout URLRequest, apiKey: String) {
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(AnthropicAPI.apiVersion, forHTTPHeaderField: "anthropic-version")
    }

    private static func isUseful(_ profile: ModelParameterProfile) -> Bool {
        profile.hasInteractiveChoices || profile.hasAutoDefaults
    }

    private static func reportHTTPFailure(
        modelIdentifier: String,
        statusCode: Int,
        data: Data
    ) {
        var message = "HTTP \(statusCode)"
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let errorMessage = error["message"] as? String {
            message += " — \(errorMessage)"
        }
        print(
            "Note: Could not load model options for '\(modelIdentifier)' (\(message)). Continuing without prompts."
        )
    }

    private static func reportNetworkFailure(modelIdentifier: String, error: Error) {
        print(
            "Note: Could not load model options for '\(modelIdentifier)' (\(error.localizedDescription)). Continuing without prompts."
        )
    }
}
