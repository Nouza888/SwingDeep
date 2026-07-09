import Foundation
import Security
import CommonCrypto

// MARK: - クライアントID管理

/// クライアントIDを管理するシングルトン
///
/// ## 機能
/// - 端末固有のUUIDを生成・管理
/// - Keychainを使用して永続化（アプリ削除後も保持）
/// - Crashlytics用のハッシュ値を生成
///
/// ## セキュリティ
/// - Keychainに保存されるため安全
/// - ハッシュ値はプライバシー保護のため8バイトに切り詰め
///
/// ## 使用例
/// ```swift
/// // クライアントIDを取得
/// let id = ClientIdManager.shared.clientId
///
/// // ハッシュ値を取得（ログ用）
/// let hash = ClientIdManager.shared.clientIdHash
/// ```
class ClientIdManager {

    // MARK: - Singleton

    static let shared = ClientIdManager()

    // MARK: - Constants

    /// Keychainに保存するためのサービス名
    private let service = "com.swingdeep.clientid"

    /// Keychainに保存するためのアカウント名
    private let account = "client_id"

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Properties

    /// クライアントID（初回アクセス時に生成・Keychain保存）
    ///
    /// - Returns: UUID形式のクライアントID
    var clientId: String {
        if let existing = getFromKeychain() {
            return existing
        }

        let newId = generateNewClientId()
        saveToKeychain(newId)
        return newId
    }

    /// クライアントIDのハッシュ値（Crashlytics用）
    ///
    /// - Returns: SHA256ハッシュの先頭8バイトを16進数文字列化したもの
    ///
    /// - Note: プライバシー保護のため先頭8バイトのみ使用
    var clientIdHash: String {
        return calculateHash(for: clientId)
    }

    // MARK: - Private Methods - ID Generation

    /// 新しいクライアントIDを生成
    private func generateNewClientId() -> String {
        return UUID().uuidString
    }

    /// 文字列のSHA256ハッシュを計算
    private func calculateHash(for string: String) -> String {
        let data = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        // 先頭8バイトのみ使用（プライバシー保護）
        return hash.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Private Methods - Keychain Operations

    /// Keychainからクライアントを取得
    ///
    /// - Returns: 保存されているクライアントID、なければnil
    private func getFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    /// Keychainにクライアントを保存
    ///
    /// - Parameter value: 保存するクライアントID
    private func saveToKeychain(_ value: String) {
        guard let data = value.data(using: .utf8) else {
            logError("Failed to convert client ID to data")
            return
        }

        // 既存のアイテムを削除
        deleteFromKeychain()

        // 新しいアイテムを追加
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            logError("Failed to save to Keychain: \(status)")
        }
    }

    /// Keychainからアイテムを削除
    private func deleteFromKeychain() {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
    }

    // MARK: - Private Methods - Logging

    /// エラーログを出力
    private func logError(_ message: String) {
        print("⚠️ [ClientIdManager] \(message)")
    }
}
