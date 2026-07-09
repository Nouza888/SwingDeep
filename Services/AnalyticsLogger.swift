import Foundation
import FirebaseAnalytics

// MARK: - Analytics Logger

/// Firebase Analyticsイベントを送信するシングルトン
///
/// ## 機能
/// - レポート生成のライフサイクルイベント
/// - ユーザーインタラクションイベント
/// - 利用制限関連イベント
///
/// ## イベント一覧
/// - `report_generate_started`: レポート生成開始
/// - `report_generate_success`: レポート生成成功
/// - `report_generate_failure`: レポート生成失敗
/// - `persona_selected`: ペルソナ選択
/// - `share_tapped`: シェアボタンタップ
/// - `video_selected`: 動画選択
/// - `diagnosis_started`: 診断開始
/// - `usage_limit_reached`: 利用回数制限到達
class AnalyticsLogger {
    
    // MARK: - Singleton
    
    static let shared = AnalyticsLogger()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Report Events
    
    /// レポート生成開始イベントを送信
    ///
    /// - Parameters:
    ///   - personaId: 選択されたペルソナID
    ///   - locale: 言語設定
    func logReportStarted(personaId: String, locale: String) {
        Analytics.logEvent("report_generate_started", parameters: [
            "persona_id": personaId,
            "locale": locale
        ])
    }
    
    /// レポート生成成功イベントを送信
    ///
    /// - Parameters:
    ///   - requestId: リクエストID
    ///   - provider: プロバイダー名
    ///   - durationMs: 処理時間（ミリ秒）
    func logReportSuccess(requestId: String, provider: String, durationMs: Int) {
        Analytics.logEvent("report_generate_success", parameters: [
            "request_id": requestId,
            "provider": provider,
            "duration_ms": durationMs
        ])
    }
    
    /// レポート生成失敗イベントを送信
    ///
    /// - Parameters:
    ///   - errorCode: エラーコード
    ///   - networkStatus: ネットワーク状態
    ///   - provider: プロバイダー名
    func logReportFailure(errorCode: String, networkStatus: String, provider: String) {
        Analytics.logEvent("report_generate_failure", parameters: [
            "error_code": errorCode,
            "network_status": networkStatus,
            "provider": provider
        ])
    }
    
    // MARK: - User Interaction Events
    
    /// ペルソナ選択イベントを送信
    ///
    /// - Parameter personaId: 選択されたペルソナID
    func logPersonaSelected(personaId: String) {
        Analytics.logEvent("persona_selected", parameters: [
            "persona_id": personaId
        ])
    }
    
    /// シェアボタンタップイベントを送信
    func logShareTapped() {
        Analytics.logEvent("share_tapped", parameters: nil)
    }
    
    /// 動画選択イベントを送信
    func logVideoSelected() {
        Analytics.logEvent("video_selected", parameters: nil)
    }
    
    /// 診断開始イベントを送信
    func logDiagnosisStarted() {
        Analytics.logEvent("diagnosis_started", parameters: nil)
    }
    
    // MARK: - Usage Events
    
    /// 利用回数制限到達イベントを送信
    ///
    /// - Parameter remainingCount: 残り回数
    func logUsageLimitReached(remainingCount: Int) {
        Analytics.logEvent("usage_limit_reached", parameters: [
            "remaining_count": remainingCount
        ])
    }
}
