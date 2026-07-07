import Foundation

public enum OpenAICompatibleAPI {

    public static let maxTokens = 4096
    public static let imagePrompt = "Describe this clipboard content."

    public static func buildUserMessage(
        content: ClipboardContent,
        supportsImages: Bool
    ) throws -> [String: Any] {
        let messageContent: Any

        switch content {
        case .text(let text):
            messageContent = text

        case .image(let imageData, let mediaType):
            guard supportsImages else {
                throw ProviderError.unsupportedContent
            }

            let dataURL = "data:\(mediaType);base64,\(imageData.base64EncodedString())"
            messageContent = [
                [
                    "type": "text",
                    "text": imagePrompt
                ] as [String: Any],
                [
                    "type": "image_url",
                    "image_url": [
                        "url": dataURL
                    ] as [String: String]
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
        if let effort = options.reasoningEffort {
            body["reasoning_effort"] = effort
        }

        if let temperature = options.temperature {
            body["temperature"] = temperature
        }

        if let topP = options.topP {
            body["top_p"] = topP
        }

        if let verbosity = options.verbosity {
            body["verbosity"] = verbosity
        }
    }

    public static func parseResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any] else {
            throw ProviderError.invalidResponse
        }

        if let text = message["content"] as? String, !text.isEmpty {
            return text
        }

        throw ProviderError.invalidResponse
    }
}
