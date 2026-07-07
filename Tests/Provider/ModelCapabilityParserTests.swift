import Foundation
import ClipAICore

enum ModelCapabilityParserTests: TestCase {
    static let name = "ModelCapabilityParserTests"

    static func run() throws {
        try testAnthropicParser()
        try testAnthropicOpus48Parser()
        try testAnthropicListParser()
        try testGeminiParser()
        try testOpenAICompatibleParser()
        try testEmptyResponses()
    }

    private static func testAnthropicParser() throws {
        let json = """
        {
          "id": "claude-sonnet-4-6",
          "capabilities": {
            "effort": {
              "supported": true,
              "low": { "supported": true },
              "medium": { "supported": true },
              "high": { "supported": true }
            },
            "thinking": {
              "supported": true,
              "types": {
                "adaptive": { "supported": true },
                "enabled": { "supported": true }
              }
            }
          }
        }
        """

        let profile = ModelCapabilityFetcher.parseResponse(kind: .anthropic, data: Data(json.utf8))
        try assertEqual(profile.reasoningEffortLevels, ["low", "medium", "high"])
        try assertTrue(profile.supportsThinkingToggle)
        try assertEqual(profile.thinkingTypes, ["adaptive", "enabled"])
        try assertFalse(profile.supportsTemperature)
    }

    private static func testAnthropicOpus48Parser() throws {
        let json = """
        {
          "id": "claude-opus-4-8",
          "capabilities": {
            "effort": {
              "supported": true,
              "low": { "supported": true },
              "medium": { "supported": true },
              "high": { "supported": true },
              "max": { "supported": true }
            },
            "thinking": {
              "supported": true,
              "types": {
                "enabled": { "supported": false },
                "adaptive": { "supported": true }
              }
            }
          }
        }
        """

        let profile = ModelCapabilityFetcher.parseResponse(kind: .anthropic, data: Data(json.utf8))
        try assertEqual(profile.reasoningEffortLevels, ["low", "medium", "high", "max"])
        try assertTrue(profile.supportsThinkingToggle)
        try assertEqual(profile.thinkingTypes, ["adaptive"])
    }

    private static func testAnthropicListParser() throws {
        let json = """
        {
          "data": [
            {
              "id": "claude-sonnet-4-6",
              "capabilities": {
                "effort": {
                  "supported": true,
                  "low": { "supported": true }
                }
              }
            },
            {
              "id": "claude-opus-4-8",
              "capabilities": {
                "effort": {
                  "supported": true,
                  "high": { "supported": true }
                },
                "thinking": {
                  "supported": true,
                  "types": {
                    "adaptive": { "supported": true }
                  }
                }
              }
            }
          ],
          "has_more": true,
          "last_id": "claude-opus-4-8"
        }
        """

        let profile = ModelCapabilityFetcher.parseAnthropicList(
            data: Data(json.utf8),
            modelIdentifier: "claude-opus-4-8"
        )
        try assertEqual(profile.reasoningEffortLevels, ["high"])
        try assertTrue(profile.supportsThinkingToggle)
        try assertEqual(profile.thinkingTypes, ["adaptive"])
    }

    private static func testGeminiParser() throws {
        let json = """
        {
          "name": "models/gemini-2.5-flash",
          "thinking": true,
          "temperature": 1.0,
          "maxTemperature": 2.0,
          "topP": 0.95
        }
        """

        let profile = ModelCapabilityFetcher.parseResponse(kind: .gemini, data: Data(json.utf8))
        try assertTrue(profile.supportsThinkingToggle)
        try assertTrue(profile.supportsTemperature)
        try assertTrue(profile.supportsTopP)
        try assertFalse(profile.supportsVerbosity)
        try assertTrue(profile.reasoningEffortLevels.isEmpty)
    }

    private static func testOpenAICompatibleParser() throws {
        let basicJSON = """
        {
          "id": "gpt-4o",
          "object": "model",
          "created": 1715367049,
          "owned_by": "system"
        }
        """
        let basicProfile = ModelCapabilityFetcher.parseResponse(kind: .openai, data: Data(basicJSON.utf8))
        try assertEqual(basicProfile, ModelParameterProfile.empty)

        let extendedJSON = """
        {
          "id": "gpt-5.5",
          "features": [
            "reasoning_effort",
            "reasoning_effort_low",
            "reasoning_effort_medium",
            "reasoning_effort_high",
            "temperature",
            "top_p",
            "variable_verbosity"
          ]
        }
        """
        let extendedProfile = ModelCapabilityFetcher.parseResponse(kind: .openai, data: Data(extendedJSON.utf8))
        try assertEqual(extendedProfile.reasoningEffortLevels, ["low", "medium", "high"])
        try assertTrue(extendedProfile.supportsThinkingToggle)
        try assertTrue(extendedProfile.supportsTemperature)
        try assertTrue(extendedProfile.supportsTopP)
        try assertTrue(extendedProfile.supportsVerbosity)
    }

    private static func testEmptyResponses() throws {
        try assertEqual(
            ModelCapabilityFetcher.parseResponse(kind: .anthropic, data: Data("{}".utf8)),
            ModelParameterProfile.empty
        )
        try assertEqual(
            ModelCapabilityFetcher.parseResponse(kind: .gemini, data: Data("not json".utf8)),
            ModelParameterProfile.empty
        )
    }
}
