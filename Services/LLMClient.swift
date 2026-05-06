import Foundation

protocol LLMClient {
    func generateReport(request: LLMRequest) async throws -> LLMResponse
}

struct LLMRequest {
    let clientId: String
    let locale: AppLanguage
    let personaId: String
    let analysisVersion: String
    let appVersion: String
    let metrics: SwingMetrics
    let systemPrompt: String
    let userPrompt: String
}

struct LLMResponse {
    let success: Bool
    let requestId: String
    let provider: String
    let personaFallback: Bool
    let reportText: String?
    let error: LLMError?
}

struct LLMError: Error {
    let code: LLMErrorCode
    let message: String
    let retryable: Bool
    var localizedDescription: String { message }
}

enum LLMErrorCode: String, Codable {
    case validationError = "VALIDATION_ERROR"
    case payloadTooLarge = "PAYLOAD_TOO_LARGE"
    case rateLimit = "RATE_LIMIT"
    case providerError = "PROVIDER_ERROR"
    case timeout = "TIMEOUT"
    case networkError = "NETWORK_ERROR"
    case unknown = "UNKNOWN"
    
    var userMessage: String {
        switch self {
        case .validationError: return "error_validation".localized
        case .payloadTooLarge: return "error_payload_too_large".localized
        case .rateLimit: return "error_rate_limit".localized
        case .providerError: return "error_provider".localized
        case .timeout: return "error_timeout".localized
        case .networkError: return "error_network".localized
        case .unknown: return "error_unknown".localized
        }
    }
}

struct LLMRequestV2 {
    let locale: AppLanguage
    let personaId: String
    let analysisVersion: String
    let appVersion: String
    let score: Int
    let itemsRanked: [ItemRanked]
    let skeletonSummaryText: String
    let reportContext: ReportContext
}

struct LLMResponseV2 {
    let success: Bool
    let requestId: String
    let personaId: String
    let analysisVersion: String
    let locale: String
    let overallBadgeTitle: String
    let overallCardText: String
    let details: [DetailItemV2]
    let metaMode: MetaMode
    let error: LLMError?
}

struct DetailItemV2: Codable {
    let key: String
    let judgmentTitle: String
    let detailText: String
    let drillIntroText: String
    let drillTitle: String
    let drillText: String
    
    enum CodingKeys: String, CodingKey {
        case key
        case judgmentTitle = "judgment_title"
        case detailText = "detail_text"
        case drillIntroText = "drill_intro_text"
        case drillTitle = "drill_title"
        case drillText = "drill_text"
    }
}

protocol LLMClientV2 {
    func generateReportV2(request: LLMRequestV2) async throws -> LLMResponseV2
}
