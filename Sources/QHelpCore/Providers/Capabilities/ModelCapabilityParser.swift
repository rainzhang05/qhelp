import Foundation

/// Parses provider Models API JSON into a capability profile.
enum ModelCapabilityParser {

    private static let effortLevelOrder = [
        "none", "minimal", "low", "medium", "high", "max", "xhigh"
    ]

    // MARK: - Anthropic

    static func parseAnthropic(_ data: Data) -> ModelParameterProfile {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let capabilities = json["capabilities"] as? [String: Any] else {
            return .empty
        }

        var profile = ModelParameterProfile()

        if let effort = capabilities["effort"] as? [String: Any] {
            profile.reasoningEffortLevels = supportedLevels(in: effort)
        }

        if let thinking = capabilities["thinking"] as? [String: Any],
           thinking["supported"] as? Bool == true {
            profile.supportsThinkingToggle = true
            if let types = thinking["types"] as? [String: Any] {
                profile.thinkingTypes = supportedThinkingTypes(in: types)
            }
        }

        return profile
    }

    // MARK: - Gemini

    static func parseGemini(_ data: Data) -> ModelParameterProfile {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .empty
        }

        var profile = ModelParameterProfile()

        if json["thinking"] as? Bool == true {
            profile.supportsThinkingToggle = true
        }

        if json["temperature"] != nil || json["maxTemperature"] != nil {
            profile.supportsTemperature = true
        }

        if json["topP"] != nil {
            profile.supportsTopP = true
        }

        return profile
    }

    // MARK: - OpenAI-compatible

    static func parseOpenAICompatible(_ data: Data) -> ModelParameterProfile {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .empty
        }

        if let capabilities = json["capabilities"] as? [String: Any] {
            let profile = parseAnthropicStyleCapabilities(capabilities)
            if profile.hasInteractiveChoices || profile.hasAutoDefaults {
                return profile
            }
        }

        if let features = json["features"] as? [String] {
            let profile = parseFeatureList(features)
            if profile.hasInteractiveChoices || profile.hasAutoDefaults {
                return profile
            }
        }

        if let parameters = json["supported_parameters"] as? [String] {
            let profile = parseParameterList(parameters)
            if profile.hasInteractiveChoices || profile.hasAutoDefaults {
                return profile
            }
        }

        return .empty
    }

    // MARK: - Shared helpers

    private static func parseAnthropicStyleCapabilities(_ capabilities: [String: Any]) -> ModelParameterProfile {
        var profile = ModelParameterProfile()

        if let effort = capabilities["effort"] as? [String: Any] {
            profile.reasoningEffortLevels = supportedLevels(in: effort)
        }

        if let thinking = capabilities["thinking"] as? [String: Any],
           thinking["supported"] as? Bool == true {
            profile.supportsThinkingToggle = true
            if let types = thinking["types"] as? [String: Any] {
                profile.thinkingTypes = supportedThinkingTypes(in: types)
            }
        }

        if capabilities["temperature"] as? Bool == true {
            profile.supportsTemperature = true
        }

        if capabilities["top_p"] as? Bool == true {
            profile.supportsTopP = true
        }

        if capabilities["verbosity"] as? Bool == true {
            profile.supportsVerbosity = true
        }

        return profile
    }

    private static func parseFeatureList(_ features: [String]) -> ModelParameterProfile {
        var profile = ModelParameterProfile()
        let normalized = Set(features.map { $0.lowercased() })

        profile.reasoningEffortLevels = reasoningLevels(from: normalized)
        profile.supportsThinkingToggle = normalized.contains("thinking")
            || normalized.contains("reasoning")
            || normalized.contains("reasoning_effort")
        profile.supportsTemperature = normalized.contains("temperature")
        profile.supportsTopP = normalized.contains("top_p")
        profile.supportsVerbosity = normalized.contains("verbosity")
            || normalized.contains("variable_verbosity")

        if profile.supportsThinkingToggle && profile.thinkingTypes.isEmpty {
            profile.thinkingTypes = ["adaptive", "enabled"]
        }

        return profile
    }

    private static func parseParameterList(_ parameters: [String]) -> ModelParameterProfile {
        parseFeatureList(parameters)
    }

    private static func reasoningLevels(from features: Set<String>) -> [String] {
        let candidates = ["none", "minimal", "low", "medium", "high", "max", "xhigh"]
        var levels: [String] = []

        if features.contains("reasoning_effort") || features.contains("reasoning") {
            for level in candidates {
                let key = "reasoning_effort_\(level)"
                if features.contains(key) || features.contains(level) {
                    levels.append(level)
                }
            }
            if levels.isEmpty {
                levels = ["low", "medium", "high"]
            }
        }

        return sortEffortLevels(levels)
    }

    static func supportedLevels(in container: [String: Any]) -> [String] {
        guard container["supported"] as? Bool == true else {
            return []
        }

        var levels: [String] = []
        for (key, value) in container {
            guard key != "supported",
                  let support = value as? [String: Any],
                  support["supported"] as? Bool == true else {
                continue
            }
            levels.append(key)
        }

        return sortEffortLevels(levels)
    }

    static func supportedThinkingTypes(in types: [String: Any]) -> [String] {
        var result: [String] = []
        for (key, value) in types {
            guard let support = value as? [String: Any],
                  support["supported"] as? Bool == true else {
                continue
            }
            result.append(key)
        }

        let preferredOrder = ["adaptive", "enabled"]
        return preferredOrder.filter { result.contains($0) }
            + result.filter { !preferredOrder.contains($0) }.sorted()
    }

    static func sortEffortLevels(_ levels: [String]) -> [String] {
        levels.sorted { lhs, rhs in
            let leftIndex = effortLevelOrder.firstIndex(of: lhs) ?? effortLevelOrder.count
            let rightIndex = effortLevelOrder.firstIndex(of: rhs) ?? effortLevelOrder.count
            return leftIndex < rightIndex
        }
    }
}
