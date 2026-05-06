import Foundation

/// アプリケーションのグローバル設定
///
/// ## 使用箇所
/// - バージョン表示（設定画面）
/// - LLMプロバイダーの切り替え
/// - デバッグフラグ
struct AppConfig {
    
    // MARK: - Version
    
    /// アプリバージョン
    static let appVersion = "1.0.0"
    
    // MARK: - LLM Settings
    
    /// LLMプロバイダー: "firebase" / "gemini"
    /// - firebase: Firebase Cloud Functions 経由 (Vertex AI)
    /// - gemini: Google AI SDK 直接呼び出し
    static let llmProvider: String = "firebase"
    
    // MARK: - Debug
    
    /// デバッグモードフラグ
    static let isDebugMode: Bool = false
}
