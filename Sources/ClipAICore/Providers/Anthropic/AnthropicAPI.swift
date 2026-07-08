import Foundation

/// Pure Anthropic Messages API helpers (request building and response parsing).
public enum AnthropicAPI {

    public static let apiVersion = "2023-06-01"
    public static let maxTokens = 4096
    public static let imagePrompt = "Describe this clipboard content."
    public static let defaultThinkingBudgetTokens = 4096

    public static func buildUserMessage(content: ClipboardContent) -> [String: Any] {
        let messageContent: Any

        switch content {
        case .text(let text):
            messageContent = text

        case .image(let imageData, let mediaType):
            messageContent = [
                [
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": mediaType,
                        "data": imageData.base64EncodedString()
                    ] as [String: String]
                ] as [String: Any],
                [
                    "type": "text",
                    "text": imagePrompt
                ] as [String: Any]
            ]
        }

        return [
            "role": "user",
            "content": messageContent
        ]
    }

    public static func buildRequestBody(
        modelIdentifier: String,
        messages: [[String: Any]],
        options: ModelRequestOptions = .none
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": modelIdentifier,
            "max_tokens": maxTokens,
            "messages": messages
        ]

        applyOptions(options, to: &body)
        return body
    }

    static func applyOptions(_ options: ModelRequestOptions, to body: inout [String: Any]) {
        if options.thinkingEnabled == true, let type = options.thinkingType {
            switch type {
            case "enabled":
                body["thinking"] = [
                    "type": "enabled",
                    "budget_tokens": defaultThinkingBudgetTokens
                ] as [String: Any]
                body["max_tokens"] = maxTokens + defaultThinkingBudgetTokens
            case "adaptive":
                body["thinking"] = ["type": "adaptive"]
            default:
                body["thinking"] = ["type": type]
            }
        }

        if let effort = options.reasoningEffort {
            body["output_config"] = ["effort": effort]
        }

        if let temperature = options.temperature {
            body["temperature"] = temperature
        }

        if let topP = options.topP {
            body["top_p"] = topP
        }
    }

    public static func parseResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArray = json["content"] as? [[String: Any]] else {
            throw ProviderError.invalidResponse
        }

        let textBlocks = contentArray.compactMap { block -> String? in
            guard block["type"] as? String == "text" else { return nil }
            return block["text"] as? String
        }

        guard !textBlocks.isEmpty else {
            throw ProviderError.invalidResponse
        }

        return textBlocks.joined(separator: "\n")
    }

    public static func parseError(statusCode: Int, data: Data, retryAfterHeader: String?) -> ProviderError {
        if statusCode == 429 {
            let retryAfter = ProviderHTTP.parseRetryAfter(retryAfterHeader)
            return .rateLimited(retryAfter: retryAfter)
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return .apiError(statusCode: statusCode, message: message)
        }

        return .apiError(statusCode: statusCode, message: "Unknown error (HTTP \(statusCode))")
    }
}
