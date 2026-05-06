import Foundation
import FirebaseCrashlytics

class CrashLogger {
    static let shared = CrashLogger()
    private init() {}
    
    func setUserContext(locale: String, personaId: String, appVersion: String, clientIdHash: String, llmProvider: String = "gemini") {
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(locale, forKey: "locale")
        crashlytics.setCustomValue(personaId, forKey: "persona_id")
        crashlytics.setCustomValue(appVersion, forKey: "app_version")
        crashlytics.setCustomValue(clientIdHash, forKey: "client_id_hash")
        crashlytics.setCustomValue(llmProvider, forKey: "llm_provider")
    }
    
    func logNonFatal(_ error: Error, context: [String: Any] = [:]) {
        let crashlytics = Crashlytics.crashlytics()
        for (key, value) in context {
            crashlytics.setCustomValue("\(value)", forKey: key)
        }
        crashlytics.record(error: error)
    }
    
    func logLLMError(_ error: LLMError, requestId: String?) {
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(error.code.rawValue, forKey: "llm_error_code")
        crashlytics.setCustomValue(error.message, forKey: "llm_error_message")
        crashlytics.setCustomValue(error.retryable, forKey: "llm_error_retryable")
        if let requestId = requestId {
            crashlytics.setCustomValue(requestId, forKey: "request_id")
        }
        let nsError = NSError(domain: "LLMError", code: error.code.hashValue, userInfo: [
            NSLocalizedDescriptionKey: error.message,
            "code": error.code.rawValue,
            "retryable": error.retryable
        ])
        crashlytics.record(error: nsError)
    }
    
    func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }
    
    #if DEBUG
    func testCrash() { fatalError("Test crash for Crashlytics") }
    #endif
}
