import Foundation
import FirebaseAnalytics

class AnalyticsLogger {
    static let shared = AnalyticsLogger()
    private init() {}
    
    func logReportStarted(personaId: String, locale: String) {
        Analytics.logEvent("report_generate_started", parameters: [
            "persona_id": personaId,
            "locale": locale
        ])
    }
    
    func logReportSuccess(requestId: String, provider: String, durationMs: Int) {
        Analytics.logEvent("report_generate_success", parameters: [
            "request_id": requestId,
            "provider": provider,
            "duration_ms": durationMs
        ])
    }
    
    func logReportFailure(errorCode: String, networkStatus: String, provider: String) {
        Analytics.logEvent("report_generate_failure", parameters: [
            "error_code": errorCode,
            "network_status": networkStatus,
            "provider": provider
        ])
    }
    
    func logPersonaSelected(personaId: String) {
        Analytics.logEvent("persona_selected", parameters: ["persona_id": personaId])
    }
    
    func logShareTapped() { Analytics.logEvent("share_tapped", parameters: nil) }
    func logVideoSelected() { Analytics.logEvent("video_selected", parameters: nil) }
    func logDiagnosisStarted() { Analytics.logEvent("diagnosis_started", parameters: nil) }
    
    func logUsageLimitReached(remainingCount: Int) {
        Analytics.logEvent("usage_limit_reached", parameters: ["remaining_count": remainingCount])
    }
}
