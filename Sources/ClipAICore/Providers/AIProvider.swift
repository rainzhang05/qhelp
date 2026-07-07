import Foundation

/// Protocol defining the interface for AI model providers.
///
/// Implement this protocol to add support for new AI providers
/// (e.g., OpenAI, Google Gemini, Ollama).
///
/// Each provider is responsible for:
/// - Authenticating with its API
/// - Formatting requests for text and image content
/// - Parsing and returning the model's response
public protocol AIProvider {

    var providerName: String { get }
    var displayName: String { get }
    var modelIdentifier: String { get }

    func send(content: ClipboardContent) async throws -> String
    func cancelInFlightRequest()
}

public extension AIProvider {
    func cancelInFlightRequest() {}
}
