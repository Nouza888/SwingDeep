import Foundation

/// アプリケーション設定ファイル
/// - Important: このファイルにはAPIキーを含めないでください
/// - Note: LLM APIキーはFirebase Functions経由で管理されます
struct AppConfig {

    // MARK: - LLM Configuration

    /// LLMプロバイダー（将来の切り替え用）
    static let llmProvider: String = "firebase"

    /// Geminiモデル名（Functions側で使用する参照値）
    static let geminiModel: String = "gemini-2.5-flash-lite"

    // MARK: - App Settings

    /// XcodeのMarketing Versionを表示する。取得できないテスト環境では復旧版の値を使う。
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.0"
    }

    /// デバッグモード
    static let isDebugMode: Bool = {
        #if DEBUG
        true
        #else
        false
        #endif
    }()
}
