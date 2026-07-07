import Foundation

/// OpenAI Chat Completions API client used by OpenAI and compatible providers.
public final class OpenAICompatibleProvider: AIProvider {

    public let providerName: String
    public let displayName: String
    public let modelIdentifier: String

    private let kind: ProviderKind
    private let apiKey: String
    private let apiURL: URL
    private let supportsImages: Bool
    private let requestOptions: ModelRequestOptions
    private let session: URLSession
    private var history: [[String: Any]] = []

    public init(
        kind: ProviderKind,
        modelIdentifier: String,
        displayName: String,
        apiKey: String,
        supportsImages: Bool,
        requestOptions: ModelRequestOptions = .none,
        session: URLSession? = nil
    ) {
        self.kind = kind
        self.providerName = kind.displayName
        self.displayName = displayName
        self.modelIdentifier = modelIdentifier
        self.apiKey = apiKey
        self.supportsImages = supportsImages
        self.requestOptions = requestOptions
        self.apiURL = ProviderCatalog.chatCompletionsURL(for: kind)!
        self.session = session ?? ProviderHTTP.makeSession()
    }

    public func send(content: ClipboardContent) async throws -> String {
        let userMessage = try OpenAICompatibleAPI.buildUserMessage(
            content: content,
            supportsImages: supportsImages
        )
        let currentMessages = history + [userMessage]

        let body = OpenAICompatibleAPI.buildRequestBody(
            modelIdentifier: modelIdentifier,
            messages: currentMessages,
            options: requestOptions
        )

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = ProviderHTTP.timeoutInterval
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let responseText = try await ProviderHTTP.performRequest(
            request,
            session: session,
            parseResponse: OpenAICompatibleAPI.parseResponse,
            parseError: ProviderHTTP.parseOpenAIError
        )
        history = currentMessages + [["role": "assistant", "content": responseText]]
        return responseText
    }

    public func cancelInFlightRequest() {
        session.invalidateAndCancel()
    }
}
