import Foundation
import Security

/// Persists provider API keys in the macOS Keychain.
enum APIKeyStore {

    private static let account = "api-key"

    static func loadKey(for kind: ProviderKind) -> String? {
        load(service: kind.keychainService, account: account)
    }

    @discardableResult
    static func saveKey(_ key: String, for kind: ProviderKind) -> Bool {
        save(key, service: kind.keychainService, account: account)
    }

    // Legacy helpers used by existing tests
    static func loadAnthropicKey() -> String? {
        loadKey(for: .anthropic)
    }

    @discardableResult
    static func saveAnthropicKey(_ key: String) -> Bool {
        saveKey(key, for: .anthropic)
    }

    static func resolveKey(for kind: ProviderKind, promptIfMissing: Bool) -> String? {
        if let envKey = ProcessInfo.processInfo.environment[kind.envVarName],
           !envKey.isEmpty {
            return envKey
        }

        if let storedKey = loadKey(for: kind) {
            return storedKey
        }

        if promptIfMissing, let enteredKey = APIKeyPrompt.readKey(for: kind) {
            if saveKey(enteredKey, for: kind) {
                return enteredKey
            }
            print("Warning: Could not save API key to Keychain. It will be used for this session only.")
            return enteredKey
        }

        return nil
    }

    // MARK: - Keychain

    private static func load(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }

        return value
    }

    private static func save(_ value: String, service: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }

        return false
    }
}
