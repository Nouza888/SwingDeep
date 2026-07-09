import Foundation
import FirebaseCrashlytics

// MARK: - Crash Logger

/// Firebase Crashlytics用のロガーシングルトン
///
/// ## 機能
/// - ユーザーコンテキストの設定
/// - 非致命的エラーの記録
/// - LLMエラーの記録
/// - ブレッドクラムの記録
///
/// ## 使用例
/// ```swift
/// // ユーザーコンテキストを設定
/// CrashLogger.shared.setUserContext(
///     locale: "ja",
///     personaId: "gentle_sister",
///     appVersion: "2.0.0",
///     clientIdHash: "abc123"
/// )
///
/// // エラーを記録
/// CrashLogger.shared.logNonFatal(error)
///
/// // ブレッドクラムを記録
/// CrashLogger.shared.log("API call started")
/// ```
class CrashLogger {

    // MARK: - Singleton

    static let shared = CrashLogger()

    // MARK: - Initialization

    private init() {}

    // MARK: - User Context

    /// ユーザーコンテキストを設定
    ///
    /// 設定された情報はCrashレポートに含まれ、問題の診断に役立ちます。
    ///
    /// - Parameters:
    ///   - locale: 言語設定（ja/en）
    ///   - personaId: 選択されたペルソナID
    ///   - appVersion: アプリバージョン
    ///   - clientIdHash: クライアントIDのハッシュ（プライバシー保護）
    ///   - llmProvider: LLMプロバイダー名（デフォルト: gemini）
    func setUserContext(
        locale: String,
        personaId: String,
        appVersion: String,
        clientIdHash: String,
        llmProvider: String = "gemini"
    ) {
        let crashlytics = Crashlytics.crashlytics()

        crashlytics.setCustomValue(locale, forKey: "locale")
        crashlytics.setCustomValue(personaId, forKey: "persona_id")
        crashlytics.setCustomValue(appVersion, forKey: "app_version")
        crashlytics.setCustomValue(clientIdHash, forKey: "client_id_hash")
        crashlytics.setCustomValue(llmProvider, forKey: "llm_provider")
    }

    // MARK: - Non-Fatal Errors

    /// 非致命的エラーを記録
    ///
    /// アプリがクラッシュしないが、記録すべきエラーを送信します。
    ///
    /// - Parameters:
    ///   - error: 記録するエラー
    ///   - context: 追加のコンテキスト情報
    func logNonFatal(_ error: Error, context: [String: Any] = [:]) {
        let crashlytics = Crashlytics.crashlytics()

        // コンテキストをカスタムキーとして設定
        for (key, value) in context {
            crashlytics.setCustomValue("\(value)", forKey: key)
        }

        crashlytics.record(error: error)
    }

    /// LLMエラーを記録
    ///
    /// LLM API呼び出しで発生したエラーを詳細に記録します。
    ///
    /// - Parameters:
    ///   - error: LLMError
    ///   - requestId: リクエストID（あれば）
    func logLLMError(_ error: LLMError, requestId: String?) {
        let crashlytics = Crashlytics.crashlytics()

        // エラー詳細をカスタムキーに設定
        crashlytics.setCustomValue(error.code.rawValue, forKey: "llm_error_code")
        crashlytics.setCustomValue(error.message, forKey: "llm_error_message")
        crashlytics.setCustomValue(error.retryable, forKey: "llm_error_retryable")

        if let requestId = requestId {
            crashlytics.setCustomValue(requestId, forKey: "request_id")
        }

        // NSErrorに変換して記録
        let nsError = NSError(
            domain: "LLMError",
            code: error.code.hashValue,
            userInfo: [
                NSLocalizedDescriptionKey: error.message,
                "code": error.code.rawValue,
                "retryable": error.retryable
            ]
        )

        crashlytics.record(error: nsError)
    }

    // MARK: - Breadcrumbs

    /// ブレッドクラムを記録
    ///
    /// クラッシュ発生時に、直前の操作を追跡するためのログを記録します。
    ///
    /// - Parameter message: 記録するメッセージ
    func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    // MARK: - Debug

    #if DEBUG
    /// テスト用クラッシュ（デバッグビルドのみ）
    ///
    /// Crashlyticsの動作確認用に意図的にクラッシュを発生させます。
    func testCrash() {
        fatalError("Test crash for Crashlytics")
    }
    #endif
}
