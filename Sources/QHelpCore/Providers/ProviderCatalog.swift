import Foundation

/// Provider metadata: routing rules and API endpoints.
public enum ProviderCatalog {

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
        if modelName.hasPrefix("claude") { return .anthropic }
        if modelName.hasPrefix("gpt")
            || modelName.hasPrefix("o1")
            || modelName.hasPrefix("o3")
            || modelName.hasPrefix("o4") { return .openai }
        if modelName.hasPrefix("gemini") { return .gemini }
        if modelName.hasPrefix("grok") { return .grok }
        if modelName.hasPrefix("kimi") || modelName.hasPrefix("moonshot") { return .kimi }
        if modelName.hasPrefix("deepseek") { return .deepseek }
        if modelName.hasPrefix("qwen") { return .qwen }
        if modelName.hasPrefix("glm") { return .glm }
        return nil
    }

    /// Returns the model name unchanged — sent verbatim to the provider API.
    public static func modelIdentifier(for modelName: String) -> String {
        modelName
    }

    public static func supportsImages(modelIdentifier: String, kind: ProviderKind) -> Bool {
        if !kind.defaultSupportsImages { return false }

        switch kind {
        case .deepseek:
            return false
        case .qwen:
            return modelIdentifier.contains("vl") || modelIdentifier.contains("vision")
        case .glm:
            return modelIdentifier.contains("v") || modelIdentifier.contains("vision")
        case .kimi:
            return modelIdentifier.contains("vision") || modelIdentifier.contains("k2")
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

    public static func anthropicModelURL(modelIdentifier: String) -> URL? {
        URL(string: "https://api.anthropic.com/v1/models/\(modelIdentifier)")
    }

    public static func geminiModelURL(modelIdentifier: String, apiKey: String) -> URL? {
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelIdentifier)")
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        return components?.url
    }

    public static func openAIModelURL(kind: ProviderKind, modelIdentifier: String) -> URL? {
        guard let base = openAICompatibleBaseURL(for: kind) else { return nil }
        return base.appendingPathComponent("models").appendingPathComponent(modelIdentifier)
    }
}
