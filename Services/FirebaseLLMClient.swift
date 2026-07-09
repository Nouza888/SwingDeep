import Foundation
import FirebaseFunctions

/// Firebase Functions経由でLLM APIを呼び出すクライアント
/// - Note: `generateReport` Callable関数を呼び出し、Gemini APIへプロキシします
class FirebaseLLMClient: LLMClient, LLMClientV2 {
    
    static let shared = FirebaseLLMClient()
    
    /// Firebase Functions参照
    /// - Note: asia-northeast1リージョンを使用
    private lazy var functions = Functions.functions(region: "asia-northeast1")
    
    /// タイムアウト設定（秒）
    private let timeoutInterval: TimeInterval = 60
    
    private init() {}
    
    // MARK: - LLMClient Protocol (V1)
    
    /// レポートを生成する
    /// - Parameter request: LLMリクエスト
    /// - Returns: LLMレスポンス
    /// - Throws: LLMError
    func generateReport(request: LLMRequest) async throws -> LLMResponse {
        let callable = functions.httpsCallable("generateReport")
        callable.timeoutInterval = timeoutInterval
        
        // リクエストデータの構築
        let data: [String: Any] = [
            "clientId": request.clientId,
            "locale": request.locale.rawValue,
            "personaId": request.personaId,
            "analysisVersion": request.analysisVersion,
            "appVersion": request.appVersion,
            "metrics": [
                "spineAngleDiffDeg": request.metrics.spineAngleDiffDeg,
                "hipMoveRatio": request.metrics.hipMoveRatio,
                "headMoveY": request.metrics.headMoveY,
                "tempoRatio": request.metrics.tempoRatio,
                "handRaiseY": request.metrics.handRaiseY,
                "swingPathType": request.metrics.swingPathType
            ],
            "systemPrompt": request.systemPrompt,
            "userPrompt": request.userPrompt
        ]
        
        do {
            // Firebase Functions呼び出し
            let result = try await callable.call(data)
            
            // レスポンスのパース
            guard let responseData = result.data as? [String: Any] else {
                throw LLMError(
                    code: .unknown,
                    message: "Invalid response format",
                    retryable: false
                )
            }
            
            return try parseResponse(responseData)
            
        } catch let error as NSError {
            // Firebase Functionsのエラーをハンドリング
            return try handleFunctionsError(error)
        }
    }
    
    // MARK: - LLMClientV2 Protocol
    
    /// V2レポートを生成する（Layer分離設計）
    /// - Parameter request: LLMRequestV2
    /// - Returns: LLMResponseV2
    /// - Throws: LLMError
    func generateReportV2(request: LLMRequestV2) async throws -> LLMResponseV2 {
        let callable = functions.httpsCallable("generateReportV2")
        callable.timeoutInterval = timeoutInterval
        
        // ItemRankedを辞書に変換
        let itemsData = request.itemsRanked.map { item -> [String: Any] in
            return [
                "key": item.key.rawValue,
                "display_name": item.displayName,
                "severity": item.severity.rawValue,
                "metrics": item.metrics
            ]
        }
        
        // リクエストデータの構築
        let data: [String: Any] = [
            "locale": request.locale.rawValue,
            "persona_id": request.personaId,
            "analysis_version": request.analysisVersion,
            "app_version": request.appVersion,
            "score": request.score,
            "items_ranked": itemsData,
            "skeleton_summary_text": request.skeletonSummaryText,
            "report_context": request.reportContext.rawValue  // ユーザーとの関係性フェーズ
        ]
        
        do {
            // Firebase Functions呼び出し
            let result = try await callable.call(data)
            
            // レスポンスのパース
            guard let responseData = result.data as? [String: Any] else {
                throw LLMError(
                    code: .unknown,
                    message: "Invalid response format",
                    retryable: false
                )
            }
            
            return try parseResponseV2(responseData)
            
        } catch let error as NSError {
            // Firebase Functionsのエラーをハンドリング
            throw try handleFunctionsErrorV2(error)
        }
    }
    
    // MARK: - Private Methods (V1)
    
    /// レスポンスをパースする
    private func parseResponse(_ data: [String: Any]) throws -> LLMResponse {
        let success = data["success"] as? Bool ?? false
        let requestId = data["requestId"] as? String ?? ""
        let provider = data["provider"] as? String ?? "gemini"
        let personaFallback = data["personaFallback"] as? Bool ?? false
        let reportText = data["reportText"] as? String
        
        // エラーチェック
        if let errorData = data["error"] as? [String: Any] {
            let codeString = errorData["code"] as? String ?? "UNKNOWN"
            let message = errorData["message"] as? String ?? "Unknown error"
            let retryable = errorData["retryable"] as? Bool ?? false
            
            let code = LLMErrorCode(rawValue: codeString) ?? .unknown
            
            return LLMResponse(
                success: false,
                requestId: requestId,
                provider: provider,
                personaFallback: personaFallback,
                reportText: nil,
                error: LLMError(code: code, message: message, retryable: retryable)
            )
        }
        
        return LLMResponse(
            success: success,
            requestId: requestId,
            provider: provider,
            personaFallback: personaFallback,
            reportText: reportText,
            error: nil
        )
    }
    
    // MARK: - Private Methods (V2)
    
    /// V2レスポンスをパースする
    private func parseResponseV2(_ data: [String: Any]) throws -> LLMResponseV2 {
        let success = data["success"] as? Bool ?? false
        let requestId = data["request_id"] as? String ?? ""
        let personaId = data["persona_id"] as? String ?? ""
        let analysisVersion = data["analysis_version"] as? String ?? ""
        let locale = data["locale"] as? String ?? ""
        let overallBadgeTitle = data["overall_badge_title"] as? String ?? ""
        let overallCardText = data["overall_card_text"] as? String ?? ""
        let metaModeString = data["meta_mode"] as? String ?? "NORMAL"
        
        // MetaModeをパース
        let metaMode: MetaMode
        switch metaModeString {
        case "EXCELLENT": metaMode = .excellent
        case "ALMOST_THERE": metaMode = .almostThere
        case "REBUILD": metaMode = .rebuild
        default: metaMode = .normal
        }
        
        // Detailsをパース
        var details: [DetailItemV2] = []
        if let detailsData = data["details"] as? [[String: Any]] {
            for detailData in detailsData {
                let detail = DetailItemV2(
                    key: detailData["key"] as? String ?? "",
                    judgmentTitle: detailData["judgment_title"] as? String ?? "",
                    detailText: detailData["detail_text"] as? String ?? "",
                    drillIntroText: detailData["drill_intro_text"] as? String ?? "",
                    drillTitle: detailData["drill_title"] as? String ?? "",
                    drillText: detailData["drill_text"] as? String ?? ""
                )
                details.append(detail)
            }
        }
        
        // エラーチェック
        if let errorData = data["error"] as? [String: Any] {
            let codeString = errorData["code"] as? String ?? "UNKNOWN"
            let message = errorData["message"] as? String ?? "Unknown error"
            let retryable = errorData["retryable"] as? Bool ?? false
            let code = LLMErrorCode(rawValue: codeString) ?? .unknown
            
            return LLMResponseV2(
                success: false,
                requestId: requestId,
                personaId: personaId,
                analysisVersion: analysisVersion,
                locale: locale,
                overallBadgeTitle: overallBadgeTitle,
                overallCardText: overallCardText,
                details: [],
                metaMode: metaMode,
                error: LLMError(code: code, message: message, retryable: retryable)
            )
        }
        
        return LLMResponseV2(
            success: success,
            requestId: requestId,
            personaId: personaId,
            analysisVersion: analysisVersion,
            locale: locale,
            overallBadgeTitle: overallBadgeTitle,
            overallCardText: overallCardText,
            details: details,
            metaMode: metaMode,
            error: nil
        )
    }
    
    /// Firebase Functionsのエラーをハンドリング
    private func handleFunctionsError(_ error: NSError) throws -> LLMResponse {
        // ネットワークエラー
        if error.domain == NSURLErrorDomain {
            throw LLMError(
                code: .networkError,
                message: "error_network".localized,
                retryable: true
            )
        }
        
        // Firebase Functionsエラー
        if error.domain == FunctionsErrorDomain {
            let code = FunctionsErrorCode(rawValue: error.code)
            
            switch code {
            case .resourceExhausted:
                // PAYLOAD_TOO_LARGE
                throw LLMError(
                    code: .payloadTooLarge,
                    message: "error_payload_too_large".localized,
                    retryable: false
                )
            case .deadlineExceeded:
                throw LLMError(
                    code: .timeout,
                    message: "error_timeout".localized,
                    retryable: true
                )
            case .unavailable:
                throw LLMError(
                    code: .providerError,
                    message: "error_provider".localized,
                    retryable: true
                )
            default:
                throw LLMError(
                    code: .unknown,
                    message: error.localizedDescription,
                    retryable: true
                )
            }
        }
        
        // その他のエラー
        throw LLMError(
            code: .unknown,
            message: error.localizedDescription,
            retryable: true
        )
    }
    
    /// V2用エラーハンドリング
    private func handleFunctionsErrorV2(_ error: NSError) throws -> LLMError {
        // ネットワークエラー
        if error.domain == NSURLErrorDomain {
            return LLMError(
                code: .networkError,
                message: "error_network".localized,
                retryable: true
            )
        }
        
        // Firebase Functionsエラー
        if error.domain == FunctionsErrorDomain {
            let code = FunctionsErrorCode(rawValue: error.code)
            
            switch code {
            case .resourceExhausted:
                return LLMError(
                    code: .payloadTooLarge,
                    message: "error_payload_too_large".localized,
                    retryable: false
                )
            case .deadlineExceeded:
                return LLMError(
                    code: .timeout,
                    message: "error_timeout".localized,
                    retryable: true
                )
            case .unavailable:
                return LLMError(
                    code: .providerError,
                    message: "error_provider".localized,
                    retryable: true
                )
            default:
                return LLMError(
                    code: .unknown,
                    message: error.localizedDescription,
                    retryable: true
                )
            }
        }
        
        // その他のエラー
        return LLMError(
            code: .unknown,
            message: error.localizedDescription,
            retryable: true
        )
    }
}

