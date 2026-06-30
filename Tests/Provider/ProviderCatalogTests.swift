import Foundation
import QHelpCore

enum ProviderCatalogTests: TestCase {
    static let name = "ProviderCatalogTests"

    static func run() throws {
        try assertEqual(ProviderCatalog.kind(for: "claude-sonnet-4-6"), .anthropic)
        try assertEqual(ProviderCatalog.kind(for: "gpt-4o"), .openai)
        try assertEqual(ProviderCatalog.kind(for: "o3-mini"), .openai)
        try assertEqual(ProviderCatalog.kind(for: "gemini-2.5-flash"), .gemini)
        try assertEqual(ProviderCatalog.kind(for: "grok-3"), .grok)
        try assertEqual(ProviderCatalog.kind(for: "kimi-k2"), .kimi)
        try assertEqual(ProviderCatalog.kind(for: "deepseek-chat"), .deepseek)
        try assertEqual(ProviderCatalog.kind(for: "qwen-plus"), .qwen)
        try assertEqual(ProviderCatalog.kind(for: "glm-4-flash"), .glm)
        try assertEqual(ProviderCatalog.kind(for: "unknown-model"), nil)

        try assertEqual(
            ProviderCatalog.modelIdentifier(for: "gpt-4o"),
            "gpt-4o"
        )
        try assertEqual(
            ProviderCatalog.modelIdentifier(for: "any-custom-model-name"),
            "any-custom-model-name"
        )

        try assertTrue(ProviderCatalog.supportsImages(modelIdentifier: "gpt-4o", kind: .openai))
        try assertFalse(ProviderCatalog.supportsImages(modelIdentifier: "deepseek-chat", kind: .deepseek))
    }
}
