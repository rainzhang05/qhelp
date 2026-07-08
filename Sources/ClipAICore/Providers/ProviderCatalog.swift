import Foundation

/// Provider metadata: routing rules and API endpoints.
public enum ProviderCatalog {
    private struct ProviderRoute {
        let kind: ProviderKind
        let prefixes: [String]

        func matches(_ modelName: String) -> Bool {
            prefixes.contains { modelName.hasPrefix($0) }
        }
    }

    private static let routes: [ProviderRoute] = [
        ProviderRoute(kind: .anthropic, prefixes: ["claude-"]),
        ProviderRoute(kind: .openai, prefixes: ["gpt-", "o1", "o3", "o4"]),
        ProviderRoute(kind: .gemini, prefixes: ["gemini-"]),
        ProviderRoute(kind: .grok, prefixes: ["grok-"]),
        ProviderRoute(kind: .kimi, prefixes: ["kimi-", "moonshot-"]),
        ProviderRoute(kind: .deepseek, prefixes: ["deepseek-"]),
        ProviderRoute(kind: .qwen, prefixes: ["qwen-"]),
        ProviderRoute(kind: .glm, prefixes: ["glm-"])
    ]

    // MARK: - Public

    /// Describes how model name prefixes map to providers (for help and errors).
    public static let routingHelp = """
      claude-*              Anthropic
      gpt-*, o1*, o3*, o4*  OpenAI
      gemini-*              Google Gemini
      grok-*                xAI Grok
      kimi-*, moonshot-*    Moonshot Kimi
      deepseek-*            DeepSeek
      qwen-*                Qwen / DashScope
      glm-*                 Zhipu GLM
    """

    public static func kind(for modelName: String) -> ProviderKind? {
        let normalized = modelName.lowercased()
        return routes.first { $0.matches(normalized) }?.kind
    }

    /// Returns the model name unchanged — sent verbatim to the provider API.
    public static func modelIdentifier(for modelName: String) -> String {
        modelName
    }

    public static func supportsImages(modelIdentifier: String, kind: ProviderKind) -> Bool {
        if !kind.defaultSupportsImages { return false }
        let normalized = modelIdentifier.lowercased()

        switch kind {
        case .deepseek:
            return false
        case .qwen:
            return normalized.contains("vl") || normalized.contains("vision")
        case .glm:
            return normalized.contains("v") || normalized.contains("vision")
        case .kimi:
            return normalized.contains("vision") || normalized.contains("k2")
        default:
            return true
        }
    }

    public static func openAICompatibleBaseURL(for kind: ProviderKind) -> URL? {
        let urlString: String
        switch kind {
        case .openai:
            urlString = "https://api.openai.com/v1"
        case .grok:
            urlString = "https://api.x.ai/v1"
        case .kimi:
            urlString = "https://api.moonshot.cn/v1"
        case .deepseek:
            urlString = "https://api.deepseek.com"
        case .qwen:
            if let override = ProcessInfo.processInfo.environment["QWEN_BASE_URL"],
               !override.isEmpty {
                urlString = override
            } else {
                urlString = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
            }
        case .glm:
            urlString = "https://open.bigmodel.cn/api/paas/v4"
        case .anthropic, .gemini:
            return nil
        }

        return URL(string: urlString)
    }

    public static func chatCompletionsURL(for kind: ProviderKind) -> URL? {
        guard let base = openAICompatibleBaseURL(for: kind) else { return nil }
        return base.appendingPathComponent("chat/completions")
    }

    public static func geminiGenerateContentURL(modelIdentifier: String, apiKey: String) -> URL? {
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelIdentifier):generateContent")
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        return components?.url
    }

    public static func normalizeGeminiModelIdentifier(_ modelIdentifier: String) -> String {
        if modelIdentifier.hasPrefix("models/") {
            return String(modelIdentifier.dropFirst("models/".count))
        }
        return modelIdentifier
    }

    public static func anthropicModelURL(modelIdentifier: String) -> URL? {
        URL(string: "https://api.anthropic.com/v1/models")?
            .appendingPathComponent(modelIdentifier)
    }

    public static func anthropicModelsListURL(after: String? = nil) -> URL? {
        var components = URLComponents(string: "https://api.anthropic.com/v1/models")
        if let after {
            components?.queryItems = [URLQueryItem(name: "after", value: after)]
        }
        return components?.url
    }

    public static func geminiModelURL(modelIdentifier: String, apiKey: String) -> URL? {
        let normalized = normalizeGeminiModelIdentifier(modelIdentifier)
        guard var components = URLComponents(
            url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models")!
                .appendingPathComponent(normalized),
            resolvingAgainstBaseURL: false
        ) else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        return components.url
    }

    public static func openAIModelURL(kind: ProviderKind, modelIdentifier: String) -> URL? {
        guard let base = openAICompatibleBaseURL(for: kind) else { return nil }
        return base.appendingPathComponent("models").appendingPathComponent(modelIdentifier)
    }
}
