import Foundation

/// Anthropic Claude API provider.
///
/// Supports text and image inputs via the Messages API.
/// Images are sent as base64-encoded data.
///
/// API reference: https://docs.anthropic.com/en/api/messages
public final class AnthropicProvider: AIProvider {

    public let providerName = "Anthropic"
    public let displayName: String
    public let modelIdentifier: String

    private let apiKey: String
    private let requestOptions: ModelRequestOptions
    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let session: URLSession
    private var history: [[String: Any]] = []

    // MARK: - Initialization

    public init(
        modelIdentifier: String,
        displayName: String,
        apiKey: String,
        requestOptions: ModelRequestOptions = .none,
        session: URLSession? = nil
    ) {
        self.modelIdentifier = modelIdentifier
        self.displayName = displayName
        self.apiKey = apiKey
        self.requestOptions = requestOptions

        if let session {
            self.session = session
        } else {
            self.session = ProviderHTTP.makeSession()
        }
    }

    // MARK: - AIProvider

    public func send(content: ClipboardContent) async throws -> String {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(AnthropicAPI.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = ProviderHTTP.timeoutInterval

        let userMessage = AnthropicAPI.buildUserMessage(content: content)
        let currentMessages = history + [userMessage]

        let body = AnthropicAPI.buildRequestBody(
            modelIdentifier: modelIdentifier,
            messages: currentMessages,
            options: requestOptions
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let responseText = try await ProviderHTTP.performRequest(
            request,
            session: session,
            parseResponse: AnthropicAPI.parseResponse,
            parseError: AnthropicAPI.parseError
        )
        history = currentMessages + [["role": "assistant", "content": responseText]]
        return responseText
    }

    public func cancelInFlightRequest() {
        session.invalidateAndCancel()
    }
}
