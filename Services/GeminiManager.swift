import Foundation

enum GeminiError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse(Int)
    case parseError(String)
    case missingData
    case llmError(LLMError)
    case usageLimitReached
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "API\u{306E}URL\u{304C}\u{4E0D}\u{6B63}\u{3067}\u{3059}"
        case .networkError(let error): return "\u{30CD}\u{30C3}\u{30C8}\u{30EF}\u{30FC}\u{30AF}\u{30A8}\u{30E9}\u{30FC}: \(error.localizedDescription)"
        case .invalidResponse(let statusCode): return "API\u{30A8}\u{30E9}\u{30FC} (HTTP \(statusCode))"
        case .parseError(let detail): return "AI\u{5FDC}\u{7B54}\u{306E}\u{89E3}\u{6790}\u{306B}\u{5931}\u{6557}: \(detail)"
        case .missingData: return "AI\u{304B}\u{3089}\u{306E}\u{5FDC}\u{7B54}\u{30C7}\u{30FC}\u{30BF}\u{304C}\u{4E0D}\u{5B8C}\u{5168}\u{3067}\u{3059}"
        case .llmError(let error): return error.code.userMessage
        case .usageLimitReached: return "error_usage_limit_reached".localized
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkError, .invalidResponse: return true
        case .llmError(let error): return error.retryable
        default: return false
        }
    }
}

class GeminiManager {
    static let shared = GeminiManager()
    private let llmClient: LLMClient = FirebaseLLMClient.shared
    private let llmClientV2: LLMClientV2 = FirebaseLLMClient.shared
    private init() {}
    
    // MARK: - V1
    
    func generateDiagnosis(metrics: SwingMetrics, coachPersona: CoachPersona) async throws -> DiagnosisReport {
        if UsageLimiter.shared.isLimitReached() {
            AnalyticsLogger.shared.logUsageLimitReached(remainingCount: 0)
            throw GeminiError.usageLimitReached
        }
        let startTime = Date()
        let language = LanguageManager.shared.currentLanguage
        AnalyticsLogger.shared.logReportStarted(personaId: coachPersona.id, locale: language.rawValue)
        CrashLogger.shared.setUserContext(locale: language.rawValue, personaId: coachPersona.id, appVersion: AppConfig.appVersion, clientIdHash: ClientIdManager.shared.clientIdHash)
        
        let systemPrompt = constructSystemInstruction(coachPersona: coachPersona)
        let inputJson = constructInputJson(metrics: metrics, userProfile: [:])
        let userPrompt = "\u{4EE5}\u{4E0B}\u{306E}\u{30B9}\u{30A4}\u{30F3}\u{30B0}\u{89E3}\u{6790}\u{30C7}\u{30FC}\u{30BF}\u{3092}\u{8A3A}\u{65AD}\u{3057}\u{3066}\u{304F}\u{3060}\u{3055}\u{3044}\u{FF1A}\n\(inputJson)"
        
        let request = LLMRequest(
            clientId: ClientIdManager.shared.clientId, locale: language, personaId: coachPersona.id,
            analysisVersion: "1.0.0", appVersion: AppConfig.appVersion, metrics: metrics,
            systemPrompt: systemPrompt, userPrompt: userPrompt
        )
        
        do {
            let response = try await llmClient.generateReport(request: request)
            if let error = response.error {
                AnalyticsLogger.shared.logReportFailure(errorCode: error.code.rawValue, networkStatus: "connected", provider: response.provider)
                CrashLogger.shared.logLLMError(error, requestId: response.requestId)
                throw GeminiError.llmError(error)
            }
            guard let reportText = response.reportText else { throw GeminiError.missingData }
            let report = try parseReportText(reportText)
            UsageLimiter.shared.recordSuccess()
            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            AnalyticsLogger.shared.logReportSuccess(requestId: response.requestId, provider: response.provider, durationMs: duration)
            if response.personaFallback { CrashLogger.shared.log("PersonaId fallback occurred for: \(coachPersona.id)") }
            return report
        } catch let error as LLMError {
            AnalyticsLogger.shared.logReportFailure(errorCode: error.code.rawValue, networkStatus: "error", provider: "gemini")
            CrashLogger.shared.logLLMError(error, requestId: nil)
            throw GeminiError.llmError(error)
        } catch {
            AnalyticsLogger.shared.logReportFailure(errorCode: "UNKNOWN", networkStatus: "error", provider: "gemini")
            throw GeminiError.networkError(error)
        }
    }
    
    // MARK: - V2 (Layer Separation)
    
    func generateDiagnosisV2(metrics: SwingMetrics, coachPersona: CoachPersona) async throws -> DiagnosisReportV2 {
        if UsageLimiter.shared.isLimitReached() {
            AnalyticsLogger.shared.logUsageLimitReached(remainingCount: 0)
            throw GeminiError.usageLimitReached
        }
        let startTime = Date()
        let language = LanguageManager.shared.currentLanguage
        AnalyticsLogger.shared.logReportStarted(personaId: coachPersona.id, locale: language.rawValue)
        CrashLogger.shared.setUserContext(locale: language.rawValue, personaId: coachPersona.id, appVersion: AppConfig.appVersion, clientIdHash: ClientIdManager.shared.clientIdHash)
        
        let itemsRanked = SeverityCalculator.calculateAll(from: metrics, language: language)
        let score = ScoreCalculator.calculate(from: itemsRanked)
        let metaMode = MetaModeCalculator.calculate(from: itemsRanked)
        let topIssueKey = itemsRanked.first(where: { $0.severity != .good })?.key
        let badgeTitle = BadgeGenerator.generate(score: score, topIssueKey: topIssueKey, metaMode: metaMode, language: language, variant: Int(Date().timeIntervalSince1970) % 5)
        let skeletonSummary = generateSkeletonSummary(items: itemsRanked, language: language)
        let reportContext = ReportContextManager.shared.determineContext()
        
        let request = LLMRequestV2(
            locale: language, personaId: coachPersona.id, analysisVersion: "v1.0", appVersion: AppConfig.appVersion,
            score: score, itemsRanked: itemsRanked, skeletonSummaryText: skeletonSummary, reportContext: reportContext
        )
        
        do {
            let response = try await llmClientV2.generateReportV2(request: request)
            if let error = response.error {
                AnalyticsLogger.shared.logReportFailure(errorCode: error.code.rawValue, networkStatus: "connected", provider: "gemini")
                CrashLogger.shared.logLLMError(error, requestId: response.requestId)
                throw GeminiError.llmError(error)
            }
            UsageLimiter.shared.recordSuccess()
            ReportContextManager.shared.recordReportGenerated()
            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            AnalyticsLogger.shared.logReportSuccess(requestId: response.requestId, provider: "gemini", durationMs: duration)
            return DiagnosisReportV2(overallBadgeTitle: response.overallBadgeTitle, overallCardText: response.overallCardText,
                                    score: score, metaMode: metaMode, details: response.details, itemsRanked: itemsRanked)
        } catch let error as LLMError {
            AnalyticsLogger.shared.logReportFailure(errorCode: error.code.rawValue, networkStatus: "error", provider: "gemini")
            CrashLogger.shared.logLLMError(error, requestId: nil)
            throw GeminiError.llmError(error)
        } catch {
            AnalyticsLogger.shared.logReportFailure(errorCode: "UNKNOWN", networkStatus: "error", provider: "gemini")
            throw GeminiError.networkError(error)
        }
    }
    
    private func generateSkeletonSummary(items: [ItemRanked], language: AppLanguage) -> String {
        let badItems = items.filter { $0.severity == .bad }
        let okItems = items.filter { $0.severity == .ok }
        let goodItems = items.filter { $0.severity == .good }
        if language == .japanese {
            var summary = "\u{3010}\u{8981}\u{7D04}\u{3011}"
            if !badItems.isEmpty { summary += "\u{8981}\u{6539}\u{5584}: \(badItems.map { $0.displayName }.joined(separator: ", "))\u{3002}" }
            if !okItems.isEmpty { summary += "\u{8981}\u{6CE8}\u{610F}: \(okItems.map { $0.displayName }.joined(separator: ", "))\u{3002}" }
            if !goodItems.isEmpty { summary += "\u{826F}\u{597D}: \(goodItems.map { $0.displayName }.joined(separator: ", "))\u{3002}" }
            return summary
        } else {
            var summary = "[Summary] "
            if !badItems.isEmpty { summary += "Needs Improvement: \(badItems.map { $0.displayName }.joined(separator: ", ")). " }
            if !okItems.isEmpty { summary += "Needs Attention: \(okItems.map { $0.displayName }.joined(separator: ", ")). " }
            if !goodItems.isEmpty { summary += "Good: \(goodItems.map { $0.displayName }.joined(separator: ", ")). " }
            return summary
        }
    }
    
    // MARK: - Private Parsing
    
    private func parseReportText(_ text: String) throws -> DiagnosisReport {
        let jsonString = extractJsonString(from: text)
        guard let jsonData = jsonString.data(using: .utf8) else { throw GeminiError.parseError("Failed to convert string to data") }
        return try JSONDecoder().decode(DiagnosisReport.self, from: jsonData)
    }
    
    private func constructSystemInstruction(coachPersona: CoachPersona) -> String {
        let language = LanguageManager.shared.currentLanguage
        return buildBasePrompt(language: language) + "\n\n" + buildPersonaPrompt(for: coachPersona)
    }
    
    private func buildBasePrompt(language: AppLanguage) -> String {
        let langInstruction = language == .japanese ? "\u{65E5}\u{672C}\u{8A9E}" : "English"
        return """
        Role: You are a professional golf coach AI. Create a diagnosis report in JSON format based on the provided data.
        Language: Output must be in \(langInstruction).

        【IMPORTANT: Variety of Expression】
        - NEVER use the same phrase twice.
        - Vary your metaphors, vocabulary, and focus points every time.
        - Example: Instead of just saying "Spine angle is bad", say "You're collapsing like a folding chair" or "You're diving into the ball".
        - Surprise the user with fresh, unique feedback every time.

        【Diagnosis Logic】
        - Assign severity (1-10) to each item.
        - 10: Fatal error destroying the swing.
        - 1: Pro-level movement.
        
        【Analysis Depth】
        - Don't just describe "what" is happening. Explain "why" it might be happening (even if it's a guess).
        - Provide a hypothesis for the cause of the error.

        【Output Format】
        Follow this JSON structure strictly:
        {
          "coach_comment": "(A short, punchy opening remark. DIFFERENT every time.)",
          "overall_summary": "(A detailed summary of the swing. 3-4 sentences. This is the most important section to show your persona. Be creative, engaging, and specific.)",
          "total_score": (Integer 0-100),
          "swing_rank": "S/A/B/C/D",
          "swing_type_name": "(Catchy name. e.g., 'Sliding Slicer', 'Rocket Launcher')",
          "diagnosis_items": [
            {
              "key": "swing_path",
              "title": "(Localized Title)",
              "status": "Bad", // Good, Check, Bad
              "severity": 9,
              "visualization_value": -80, // -100(In) ~ 0 ~ +100(Out)
              "comment": "(Sharp, unique, and detailed feedback. Explain WHY.)",
              "drill": {
                "title": "(Drill Name)",
                "description": "(How to do it)"
              }
            },
            ... (6 items: swing_path, hand_position, early_extension, spine_angle, head_level, tempo)
          ]
        }
        """
    }
    
    private func buildPersonaPrompt(for persona: CoachPersona) -> String {
        """
        【Persona Definition】
        Name: \(persona.name)
        Role: \(persona.description)
        System Instruction: \(persona.systemPrompt)
        """
    }
    
    private func constructInputJson(metrics: SwingMetrics, userProfile: [String: Any]) -> String {
        let inputData: [String: Any] = [
            "user_profile": userProfile,
            "metrics": [
                "spine_angle_diff_deg": metrics.spineAngleDiffDeg,
                "hip_move_ratio": metrics.hipMoveRatio,
                "head_move_y": metrics.headMoveY,
                "tempo_ratio": metrics.tempoRatio,
                "hand_raise_y": metrics.handRaiseY,
                "swing_path_type": metrics.swingPathType
            ],
            "request_variation_seed": Int.random(in: 1...100000)
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: inputData, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) { return jsonString }
        return "{}"
    }
    
    private func parseGeminiResponse(_ data: Data) throws -> DiagnosisReport {
        struct GeminiResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]?
        }
        let geminiResp = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = geminiResp.candidates?.first?.content.parts.first?.text else {
            throw NSError(domain: "GeminiManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "\u{30EC}\u{30B9}\u{30DD}\u{30F3}\u{30B9}\u{306B}\u{30B3}\u{30F3}\u{30C6}\u{30F3}\u{30C4}\u{304C}\u{542B}\u{307E}\u{308C}\u{3066}\u{3044}\u{307E}\u{305B}\u{3093}"])
        }
        let jsonString = extractJsonString(from: text)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "GeminiManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to convert string to data"])
        }
        return try JSONDecoder().decode(DiagnosisReport.self, from: jsonData)
    }
    
    private func extractJsonString(from text: String) -> String {
        if let rangeStart = text.range(of: "{"), let rangeEnd = text.range(of: "}", options: .backwards) {
            if rangeStart.lowerBound < rangeEnd.upperBound { return String(text[rangeStart.lowerBound..<rangeEnd.upperBound]) }
        }
        return text
    }
}

struct CoachPersona: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let themeColorHex: String
    let systemPrompt: String
    
    static var standard: CoachPersona { availablePersonas(for: LanguageManager.shared.currentLanguage).first! }
    
    static func availablePersonas(for language: AppLanguage) -> [CoachPersona] {
        let personaConfigs: [(id: String, icon: String, themeColorHex: String)] = [
            ("gentle_sister", "\u{1F469}", "FF2D55"), ("spartan", "\u{1FA96}", "FF3B30"),
            ("standard", "\u{1F916}", "007AFF"), ("comedian", "\u{1F3A4}", "AF52DE"),
            ("gal", "\u{1F496}", "FF9500"), ("toxic_pro", "\u{1F3AF}", "34C759")
        ]
        return personaConfigs.map { config in
            let name = LanguageManager.shared.localized("coach_\(config.id)")
            let desc = LanguageManager.shared.localized("desc_\(config.id)")
            let quote = LanguageManager.shared.localized("quote_\(config.id)")
            return CoachPersona(id: config.id, name: name, description: "\(desc)\n\(quote)",
                              icon: config.icon, themeColorHex: config.themeColorHex, systemPrompt: "")
        }
    }
    
    static var normal: CoachPersona { availablePersonas(for: LanguageManager.shared.currentLanguage).first { $0.id == "standard" } ?? standard }
    static var spartan: CoachPersona { availablePersonas(for: LanguageManager.shared.currentLanguage).first { $0.id == "spartan" } ?? standard }
    static var kind: CoachPersona { availablePersonas(for: LanguageManager.shared.currentLanguage).first { $0.id == "gentle_sister" } ?? standard }
    static var kansaiMom: CoachPersona { availablePersonas(for: LanguageManager.shared.currentLanguage).first { $0.id == "gal" } ?? standard }
    static var comedian: CoachPersona { availablePersonas(for: LanguageManager.shared.currentLanguage).first { $0.id == "comedian" } ?? standard }
}

typealias CoachMode = CoachPersona
