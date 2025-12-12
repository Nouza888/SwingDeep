import Foundation
/// アプリケーション設定ファイル
/// - Important: このファイルは.gitignoreに追加し、リポジトリにコミットしないでください
/// - Note: ローカル開発用の設定値を管理します
struct AppConfig {
    
    // MARK: - Gemini API Configuration
    
    /// Gemini APIキー
    /// - Important: Google AI Studio (https://aistudio.google.com/app/apikey) で取得したキーを設定してください
    /// - Warning: このキーは秘密情報です。絶対にGitにコミットしないでください
    static let geminiApiKey: String = "AIzaSyDxIc3H5n02FLvZ3zWckTqfjoIIKtKKh0k"
    
    /// Gemini APIのモデル名
    /// - Note: gemini-2.5-flash-lite を使用（コスト最適化・MVP段階）
    static let geminiModel: String = "gemini-2.5-flash-lite"
    
    /// Gemini APIのベースURL
    static let geminiBaseURL: String = "https://generativelanguage.googleapis.com/v1beta/models"
    
    // MARK: - App Settings
    
    /// アプリのバージョン
    static let appVersion: String = "2.0.0"
    
    /// デバッグモード
    static let isDebugMode: Bool = true
}
