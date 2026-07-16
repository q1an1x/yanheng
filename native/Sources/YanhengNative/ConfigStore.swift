import Foundation
import Security

struct YanhengConfig: Codable, Equatable {
    var baseURL: String = "http://127.0.0.1:8080"
    var adminAPIKey: String = ""
    var refreshMinutes: Double = 5
    var warningRemainingPercent: Double = 25
    var minimumAvailableAccounts: Int = 2
    var minimumAvailablePercent: Double = 30

    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url"
        case adminAPIKey = "admin_api_key"
        case refreshMinutes = "refresh_minutes"
        case warningRemainingPercent = "warning_remaining_percent"
        case minimumAvailableAccounts = "minimum_available_accounts"
        case minimumAvailablePercent = "minimum_available_percent"
    }

    mutating func normalize() {
        baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while baseURL.hasSuffix("/") { baseURL.removeLast() }
        if baseURL.hasSuffix("/api/v1") { baseURL.removeLast(7) }
        refreshMinutes = min(max(refreshMinutes, 1), 60)
        warningRemainingPercent = min(max(warningRemainingPercent, 1), 99)
        minimumAvailableAccounts = min(max(minimumAvailableAccounts, 1), 10_000)
        minimumAvailablePercent = min(max(minimumAvailablePercent, 1), 100)
    }
}

enum ConfigStore {
    private static let defaults = UserDefaults.standard
    private static let service = "dev.yanxu.yanheng"
    private static let account = "sub2api-admin-api-key"

    static func load() -> YanhengConfig {
        var config = YanhengConfig()
        config.baseURL = defaults.string(forKey: "baseURL") ?? config.baseURL
        config.refreshMinutes = defaults.object(forKey: "refreshMinutes") as? Double ?? config.refreshMinutes
        config.warningRemainingPercent = defaults.object(forKey: "warningRemainingPercent") as? Double ?? config.warningRemainingPercent
        config.minimumAvailableAccounts = defaults.object(forKey: "minimumAvailableAccounts") as? Int ?? config.minimumAvailableAccounts
        config.minimumAvailablePercent = defaults.object(forKey: "minimumAvailablePercent") as? Double ?? config.minimumAvailablePercent
        config.adminAPIKey = loadKeychainValue() ?? ""
        config.normalize()
        return config
    }

    static func save(_ input: YanhengConfig) throws {
        var config = input
        config.normalize()
        guard let url = URL(string: config.baseURL), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            throw ConfigError.invalidURL
        }
        defaults.set(config.baseURL, forKey: "baseURL")
        defaults.set(config.refreshMinutes, forKey: "refreshMinutes")
        defaults.set(config.warningRemainingPercent, forKey: "warningRemainingPercent")
        defaults.set(config.minimumAvailableAccounts, forKey: "minimumAvailableAccounts")
        defaults.set(config.minimumAvailablePercent, forKey: "minimumAvailablePercent")
        try saveKeychainValue(config.adminAPIKey)
    }

    private static func loadKeychainValue() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func saveKeychainValue(_ value: String) throws {
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(identity as CFDictionary)
        guard !value.isEmpty else { return }
        var item = identity
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw ConfigError.keychain(status) }
    }
}

enum ConfigError: LocalizedError {
    case invalidURL
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "服务地址必须是有效的 HTTP 或 HTTPS 地址"
        case .keychain(let status): return "无法写入钥匙串（\(status)）"
        }
    }
}
