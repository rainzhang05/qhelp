import Foundation

/// User-selected and auto-applied model parameters for API requests.
public struct ModelRequestOptions: Equatable, Sendable {
    public static let defaultTemperature = 0.0
    public static let defaultTopP = 1.0
    public static let defaultVerbosity = "medium"

    public var reasoningEffort: String?
    public var thinkingEnabled: Bool?
    public var thinkingType: String?
    public var temperature: Double?
    public var topP: Double?
    public var verbosity: String?

    public init(
        reasoningEffort: String? = nil,
        thinkingEnabled: Bool? = nil,
        thinkingType: String? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        verbosity: String? = nil
    ) {
        self.reasoningEffort = reasoningEffort
        self.thinkingEnabled = thinkingEnabled
        self.thinkingType = thinkingType
        self.temperature = temperature
        self.topP = topP
        self.verbosity = verbosity
    }

    public static let none = ModelRequestOptions()

    public static func defaults(for profile: ModelParameterProfile) -> ModelRequestOptions {
        var options = ModelRequestOptions()
        options.applyAutoDefaults(for: profile)
        return options
    }

    public mutating func applyAutoDefaults(for profile: ModelParameterProfile) {
        if profile.supportsTemperature {
            temperature = Self.defaultTemperature
        }

        if profile.supportsTopP {
            topP = Self.defaultTopP
        }

        if profile.supportsVerbosity {
            verbosity = Self.defaultVerbosity
        }
    }
}
