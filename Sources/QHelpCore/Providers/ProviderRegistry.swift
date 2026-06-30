import Foundation

/// Registry for resolving model aliases to AI provider instances.
public enum ProviderRegistry {

    // MARK: - Public Interface

    public static var availableModels: [String] {
        ProviderCatalog.allModelAliases
    }

    public static func resolve(modelAlias: String) -> AIProvider? {
        guard let kind = ProviderCatalog.kind(for: modelAlias) else {
            return nil
        }

        guard let apiKey = APIKeyStore.resolveKey(for: kind, promptIfMissing: true),
              !apiKey.isEmpty else {
            print("Error: No \(kind.displayName) API key found.")
            print("Set \(kind.envVarName) or enter your key when prompted.")
            exit(1)
        }

        let modelIdentifier = ProviderCatalog.modelIdentifier(for: modelAlias, kind: kind)
        let supportsImages = ProviderCatalog.supportsImages(
            modelIdentifier: modelIdentifier,
            kind: kind
        )

        switch kind {
        case .anthropic:
            return AnthropicProvider(
                modelIdentifier: modelIdentifier,
                displayName: modelAlias,
                apiKey: apiKey
            )

        case .openai, .grok, .kimi, .deepseek, .qwen, .glm:
            return OpenAICompatibleProvider(
                kind: kind,
                modelIdentifier: modelIdentifier,
                displayName: modelAlias,
                apiKey: apiKey,
                supportsImages: supportsImages
            )

        case .gemini:
            return GeminiProvider(
                modelIdentifier: modelIdentifier,
                displayName: modelAlias,
                apiKey: apiKey,
                supportsImages: supportsImages
            )
        }
    }

    // MARK: - Testing Helpers

    public static func makeAnthropicProvider(modelAlias: String, apiKey: String) -> AIProvider {
        AnthropicProvider(
            modelIdentifier: ProviderCatalog.modelIdentifier(for: modelAlias, kind: .anthropic),
            displayName: modelAlias,
            apiKey: apiKey
        )
    }

    public static func anthropicAPIKey(promptIfMissing: Bool = false) -> String? {
        APIKeyStore.resolveKey(for: .anthropic, promptIfMissing: promptIfMissing)
    }

    public static func anthropicModelIdentifier(for alias: String) -> String {
        ProviderCatalog.modelIdentifier(for: alias, kind: .anthropic)
    }

    public static func providerKind(for modelAlias: String) -> ProviderKind? {
        ProviderCatalog.kind(for: modelAlias)
    }
}
