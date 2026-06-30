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
        guard let request = makeRequest(kind: kind, modelIdentifier: modelIdentifier, apiKey: apiKey) else {
            return .empty
        }

        do {
            let data = try await ProviderHTTP.fetchData(request, session: session)
            return parseResponse(kind: kind, data: data)
        } catch {
            fputs("Warning: Could not fetch model capabilities (\(error.localizedDescription)).\n", stderr)
            return .empty
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
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue(AnthropicAPI.apiVersion, forHTTPHeaderField: "anthropic-version")
        case .gemini:
            break
        case .openai, .grok, .kimi, .deepseek, .qwen, .glm:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}
