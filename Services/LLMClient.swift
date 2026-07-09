import Foundation

// MARK: - LLM Client Protocol

/// LLMクライアントプロトコル
/// 将来のFull Backend移行（Genkit等）に備えた抽象化層
protocol LLMClient {
    func generateReport(request: LLMRequest) async throws -> LLMResponse
}

// MARK: - Request / Response Types

/// LLMリクエスト
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

/// LLMレスポンス
struct LLMResponse {
    let success: Bool
    let requestId: String
    let provider: String
    let personaFallback: Bool
    let reportText: String?
    let error: LLMError?
}

/// LLMエラー
struct LLMError: Error {
    let code: LLMErrorCode
    let message: String
    let retryable: Bool
    
    var localizedDescription: String { message }
}

/// LLMエラーコード（Functions側と一致）
enum LLMErrorCode: String, Codable {
    case validationError = "VALIDATION_ERROR"
    case payloadTooLarge = "PAYLOAD_TOO_LARGE"
    case rateLimit = "RATE_LIMIT"
    case providerError = "PROVIDER_ERROR"
    case timeout = "TIMEOUT"
    case networkError = "NETWORK_ERROR"
    case unknown = "UNKNOWN"
    
    /// ユーザー向けメッセージ（ローカライズ対応）
    var userMessage: String {
        switch self {
        case .validationError:
            return "error_validation".localized
        case .payloadTooLarge:
            return "error_payload_too_large".localized
        case .rateLimit:
            return "error_rate_limit".localized
        case .providerError:
            return "error_provider".localized
        case .timeout:
            return "error_timeout".localized
        case .networkError:
            return "error_network".localized
        case .unknown:
            return "error_unknown".localized
        }
    }
}

// MARK: - V2 Types (Layer分離設計)

/// V2リクエスト（構造化データのみ送信）
struct LLMRequestV2 {
    let locale: AppLanguage
    let personaId: String
    let analysisVersion: String
    let appVersion: String
    let score: Int
    let itemsRanked: [ItemRanked]
    let skeletonSummaryText: String
    let reportContext: ReportContext  // ユーザーとの関係性フェーズ
}

/// V2レスポンス
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

/// 詳細項目（V2）
struct DetailItemV2: Codable {
    let key: String
    let judgmentTitle: String   // 判定タイトル（7〜14文字）
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

/// V2対応プロトコル
protocol LLMClientV2 {
    func generateReportV2(request: LLMRequestV2) async throws -> LLMResponseV2
}
