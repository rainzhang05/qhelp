import Foundation

/// Interactive terminal prompts for model options supported by provider metadata.
public enum ModelOptionsPrompt {

    public typealias LineReader = () -> String?

    private static var lineReader: LineReader = { readLine() }

    /// Overrides stdin for tests. Pass `nil` to restore default `readLine()`.
    public static func setLineReader(_ reader: LineReader?) {
        lineReader = reader ?? { readLine() }
    }

    public static func prompt(for profile: ModelParameterProfile) -> ModelRequestOptions {
        guard profile.hasInteractiveChoices || profile.hasAutoDefaults else {
            return .none
        }

        var options = ModelRequestOptions()
        var thinkingEnabled: Bool?

        if profile.supportsThinkingToggle {
            thinkingEnabled = promptThinkingToggle()
            options.thinkingEnabled = thinkingEnabled
            if thinkingEnabled == true {
                options.thinkingType = preferredThinkingType(from: profile.thinkingTypes)
            }
        }

        let shouldPromptEffort = !profile.reasoningEffortLevels.isEmpty
            && (thinkingEnabled == true || !profile.supportsThinkingToggle)

        if shouldPromptEffort,
           let effort = promptReasoningEffort(levels: profile.reasoningEffortLevels) {
            options.reasoningEffort = effort
        }

        if profile.supportsTemperature {
            options.temperature = 0.0
        }

        if profile.supportsTopP {
            options.topP = 1.0
        }

        if profile.supportsVerbosity {
            options.verbosity = "low"
        }

        return options
    }

    static func preferredThinkingType(from types: [String]) -> String? {
        if types.contains("adaptive") { return "adaptive" }
        if types.contains("enabled") { return "enabled" }
        return types.first
    }

    private static func promptThinkingToggle() -> Bool {
        print("")
        print("Enable extended thinking? [y/N]")
        let input = lineReader()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return input == "y" || input == "yes"
    }

    private static func promptReasoningEffort(levels: [String]) -> String? {
        guard !levels.isEmpty else { return nil }

        print("")
        print("Reasoning effort:")
        for (index, level) in levels.enumerated() {
            print("  \(index + 1)) \(level)")
        }

        let defaultIndex = defaultEffortIndex(in: levels)
        print("Choice [\(defaultIndex + 1)]:")
        let input = lineReader()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if input.isEmpty {
            return levels[defaultIndex]
        }

        if let number = Int(input), number >= 1, number <= levels.count {
            return levels[number - 1]
        }

        if levels.contains(input) {
            return input
        }

        return levels[defaultIndex]
    }

    private static func defaultEffortIndex(in levels: [String]) -> Int {
        if let mediumIndex = levels.firstIndex(of: "medium") {
            return mediumIndex
        }
        return min(1, levels.count - 1)
    }
}
