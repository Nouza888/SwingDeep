import Foundation

/// Gemini API通信時のエラー種別
enum GeminiError: LocalizedError {
    case invalidURL                    // URLが不正
    case networkError(Error)           // ネットワークエラー
    case invalidResponse(Int)          // HTTPステータスコードが200以外
    case parseError(String)            // JSONパース失敗
    case missingData                   // 必要なデータが不足
    case llmError(LLMError)            // Firebase Functions経由のエラー
    case usageLimitReached             // 利用回数制限

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "APIのURLが不正です"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .invalidResponse(let statusCode):
            return "APIエラー (HTTP \(statusCode))"
        case .parseError(let detail):
            return "AI応答の解析に失敗: \(detail)"
        case .missingData:
            return "AIからの応答データが不完全です"
        case .llmError(let error):
            return error.code.userMessage
        case .usageLimitReached:
            return "error_usage_limit_reached".localized
        }
    }

    /// リトライ可能なエラーかどうか
    var isRetryable: Bool {
        switch self {
        case .networkError, .invalidResponse:
            return true
        case .llmError(let error):
            return error.retryable
        default:
            return false
        }
    }
}

/// Google Gemini APIとの通信を管理するクラス
///
/// Firebase Functions経由でGemini APIを呼び出し、スイング解析データから
/// 詳細な診断レポートを生成します。
///
/// ## 主な機能
/// - コーチペルソナに応じたプロンプト生成
/// - JSON形式での診断レポート取得
/// - Firebase Functions経由でのセキュアなAPI呼び出し
///
/// - Note: シングルトンパターンで実装されています
/// - Important: APIキーはFirebase Functions側で管理されます
class GeminiManager {
    static let shared = GeminiManager()

    /// LLMクライアント（Firebase Functions経由）- V1
    private let llmClient: LLMClient = FirebaseLLMClient.shared

    /// LLMクライアント V2（Layer分離設計）
    private let llmClientV2: LLMClientV2 = FirebaseLLMClient.shared

    private init() {}

    // MARK: - Public Methods (公開メソッド)

    /// スイング解析データに基づいて診断レポートを生成する
    ///
    /// このメソッドは以下の処理を実行します：
    /// 1. 利用回数制限のチェック
    /// 2. システムプロンプトの構築（コーチペルソナ反映）
    /// 3. Firebase Functions経由でのAPI呼び出し
    /// 4. レスポンスのパースと検証
    /// 5. 成功時に利用回数をカウント
    ///
    /// - Parameters:
    ///   - metrics: 解析済みスイングメトリクス（背骨角度、腰の移動、頭の位置など）
    ///   - coachPersona: 選択されたコーチペルソナ（鬼軍曹、関西おかんなど）
    /// - Returns: 診断レポート（DiagnosisReport）
    /// - Throws: GeminiError - API通信またはパースに失敗した場合
    func generateDiagnosis(metrics: SwingMetrics, coachPersona: CoachPersona) async throws -> DiagnosisReport {
        // 利用回数制限チェック
        if UsageLimiter.shared.isLimitReached() {
            AnalyticsLogger.shared.logUsageLimitReached(remainingCount: 0)
            throw GeminiError.usageLimitReached
        }

        let startTime = Date()
        let language = LanguageManager.shared.currentLanguage

        // Analyticsイベント：開始
        AnalyticsLogger.shared.logReportStarted(
            personaId: coachPersona.id,
            locale: language.rawValue
        )

        // Crashlyticsコンテキスト設定
        CrashLogger.shared.setUserContext(
            locale: language.rawValue,
            personaId: coachPersona.id,
            appVersion: AppConfig.appVersion,
            clientIdHash: ClientIdManager.shared.clientIdHash
        )

        // プロンプト構築
        let systemPrompt = constructSystemInstruction(coachPersona: coachPersona)
        let inputJson = constructInputJson(metrics: metrics, userProfile: [:])
        let userPrompt = "以下のスイング解析データを診断してください：\n\(inputJson)"

        // LLMリクエスト作成
        let request = LLMRequest(
            clientId: ClientIdManager.shared.clientId,
            locale: language,
            personaId: coachPersona.id,
            analysisVersion: "1.0.0",
            appVersion: AppConfig.appVersion,
            metrics: metrics,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )

        do {
            // Firebase Functions経由でAPI呼び出し
            let response = try await llmClient.generateReport(request: request)

            // エラーチェック
            if let error = response.error {
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                AnalyticsLogger.shared.logReportFailure(
                    errorCode: error.code.rawValue,
                    networkStatus: "connected",
                    provider: response.provider
                )
                CrashLogger.shared.logLLMError(error, requestId: response.requestId)
                throw GeminiError.llmError(error)
            }

            // レスポンステキストのパース
            guard let reportText = response.reportText else {
                throw GeminiError.missingData
            }

            let report = try parseReportText(reportText)

            // 成功！利用回数をカウント
            UsageLimiter.shared.recordSuccess()

            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            AnalyticsLogger.shared.logReportSuccess(
                requestId: response.requestId,
                provider: response.provider,
                durationMs: duration
            )

            // ペルソナフォールバック時のログ
            if response.personaFallback {
                CrashLogger.shared.log("PersonaId fallback occurred for: \(coachPersona.id)")
            }

            return report

        } catch let error as LLMError {
            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            AnalyticsLogger.shared.logReportFailure(
                errorCode: error.code.rawValue,
                networkStatus: "error",
                provider: "gemini"
            )
            CrashLogger.shared.logLLMError(error, requestId: nil)
            throw GeminiError.llmError(error)
        } catch {
            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            AnalyticsLogger.shared.logReportFailure(
                errorCode: "UNKNOWN",
                networkStatus: "error",
                provider: "gemini"
            )
            throw GeminiError.networkError(error)
        }
    }

    // MARK: - V2 Public Methods (Layer分離設計)

    /// V2: スイング解析データに基づいて診断レポートを生成する（Layer分離設計）
    ///
    /// - Parameters:
    ///   - metrics: 解析済みスイングメトリクス
    ///   - coachPersona: 選択されたコーチペルソナ
    /// - Returns: 診断レポートV2
    /// - Throws: GeminiError
    func generateDiagnosisV2(metrics: SwingMetrics, coachPersona: CoachPersona) async throws -> DiagnosisReportV2 {
        // 利用回数制限チェック
        if UsageLimiter.shared.isLimitReached() {
            AnalyticsLogger.shared.logUsageLimitReached(remainingCount: 0)
            throw GeminiError.usageLimitReached
        }

        let startTime = Date()
        let language = LanguageManager.shared.currentLanguage

        // Analyticsイベント：開始
        AnalyticsLogger.shared.logReportStarted(
            personaId: coachPersona.id,
            locale: language.rawValue
        )

        // Crashlyticsコンテキスト設定
        CrashLogger.shared.setUserContext(
            locale: language.rawValue,
            personaId: coachPersona.id,
            appVersion: AppConfig.appVersion,
            clientIdHash: ClientIdManager.shared.clientIdHash
        )

        // severity計算（iOS側で実行）
        let itemsRanked = SeverityCalculator.calculateAll(from: metrics, language: language)

        // スコア計算
        let score = ScoreCalculator.calculate(from: itemsRanked)

        // metaモード判定
        let metaMode = MetaModeCalculator.calculate(from: itemsRanked)

        // バッジ生成
        let topIssueKey = itemsRanked.first(where: { $0.severity != .good })?.key
        let badgeTitle = BadgeGenerator.generate(
            score: score,
            topIssueKey: topIssueKey,
            metaMode: metaMode,
            language: language,
            variant: Int(Date().timeIntervalSince1970) % 5
        )

        // スケルトンサマリー生成
        let skeletonSummary = generateSkeletonSummary(items: itemsRanked, language: language)

        // report_context を決定
        let reportContext = ReportContextManager.shared.determineContext()

        // V2リクエスト作成
        let request = LLMRequestV2(
            locale: language,
            personaId: coachPersona.id,
            analysisVersion: "v1.0",
            appVersion: AppConfig.appVersion,
            score: score,
            itemsRanked: itemsRanked,
            skeletonSummaryText: skeletonSummary,
            reportContext: reportContext
        )

        do {
            // Firebase Functions V2呼び出し
            let response = try await llmClientV2.generateReportV2(request: request)

            // エラーチェック
            if let error = response.error {
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                AnalyticsLogger.shared.logReportFailure(
                    errorCode: error.code.rawValue,
                    networkStatus: "connected",
                    provider: "gemini"
                )
                CrashLogger.shared.logLLMError(error, requestId: response.requestId)
                throw GeminiError.llmError(error)
            }

            // 成功！利用回数をカウント
            UsageLimiter.shared.recordSuccess()

            // レポート回数を記録（report_context用）
            ReportContextManager.shared.recordReportGenerated()

            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            AnalyticsLogger.shared.logReportSuccess(
                requestId: response.requestId,
                provider: "gemini",
                durationMs: duration
            )

            // DiagnosisReportV2を構築
            let report = DiagnosisReportV2(
                overallBadgeTitle: response.overallBadgeTitle,
                overallCardText: response.overallCardText,
                score: score,
                metaMode: metaMode,
                details: response.details,
                itemsRanked: itemsRanked
            )

            return report

        } catch let error as LLMError {
            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            AnalyticsLogger.shared.logReportFailure(
                errorCode: error.code.rawValue,
                networkStatus: "error",
                provider: "gemini"
            )
            CrashLogger.shared.logLLMError(error, requestId: nil)
            throw GeminiError.llmError(error)
        } catch {
            AnalyticsLogger.shared.logReportFailure(
                errorCode: "UNKNOWN",
                networkStatus: "error",
                provider: "gemini"
            )
            throw GeminiError.networkError(error)
        }
    }

    /// スケルトンサマリーを生成
    private func generateSkeletonSummary(items: [ItemRanked], language: AppLanguage) -> String {
        let badItems = items.filter { $0.severity == .bad }
        let okItems = items.filter { $0.severity == .ok }
        let goodItems = items.filter { $0.severity == .good }

        if language == .japanese {
            var summary = "【要約】"
            if !badItems.isEmpty {
                summary += "要改善: \(badItems.map { $0.displayName }.joined(separator: ", "))。"
            }
            if !okItems.isEmpty {
                summary += "要注意: \(okItems.map { $0.displayName }.joined(separator: ", "))。"
            }
            if !goodItems.isEmpty {
                summary += "良好: \(goodItems.map { $0.displayName }.joined(separator: ", "))。"
            }
            return summary
        } else {
            var summary = "[Summary] "
            if !badItems.isEmpty {
                summary += "Needs Improvement: \(badItems.map { $0.displayName }.joined(separator: ", ")). "
            }
            if !okItems.isEmpty {
                summary += "Needs Attention: \(okItems.map { $0.displayName }.joined(separator: ", ")). "
            }
            if !goodItems.isEmpty {
                summary += "Good: \(goodItems.map { $0.displayName }.joined(separator: ", ")). "
            }
            return summary
        }
    }

    // MARK: - Private Methods - Response Parsing

    /// レスポンステキストをパースしてDiagnosisReportに変換する
    private func parseReportText(_ text: String) throws -> DiagnosisReport {
        // JSON文字列部分を抽出（Markdownのコードブロック対策）
        let jsonString = extractJsonString(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw GeminiError.parseError("Failed to convert string to data")
        }

        do {
            return try JSONDecoder().decode(DiagnosisReport.self, from: jsonData)
        } catch {
            throw GeminiError.parseError(error.localizedDescription)
        }
    }

    // MARK: - System Prompt Construction (システムプロンプト構築)

    /// システムプロンプトを構築する（統合メソッド）
    /// - Parameters:
    ///   - coachPersona: 選択されたコーチのペルソナ
    /// - Returns: 構築されたシステムプロンプト文字列
    private func constructSystemInstruction(coachPersona: CoachPersona) -> String {
        let language = LanguageManager.shared.currentLanguage

        // 1. 基本プロンプトの構築
        var prompt = buildBasePrompt(language: language)

        // 2. ペルソナプロンプトの追加
        prompt += "\n\n" + buildPersonaPrompt(for: coachPersona)

        return prompt
    }

    /// 基本プロンプトを構築（役割定義・診断ロジック・出力形式）
    ///
    /// ## 含まれる要素
    /// - AI の役割（プロゴルフコーチ）
    /// - 出力言語の指定
    /// - 表現のバリエーション要求
    /// - 診断ロジック（severity 1-10 の基準）
    /// - 分析の深さ（原因仮説の提示）
    /// - JSON 出力フォーマットの詳細定義
    ///
    /// - Parameter language: 出力言語（日本語 or English）
    /// - Returns: 基本プロンプト文字列
    private func buildBasePrompt(language: AppLanguage) -> String {
        let langInstruction = language == .japanese ? "日本語" : "English"

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

    /// ペルソナプロンプトを構築（CoachPersona構造体から直接取得）
    private func buildPersonaPrompt(for persona: CoachPersona) -> String {
        return """
        【Persona Definition】
        Name: \(persona.name)
        Role: \(persona.description)
        System Instruction: \(persona.systemPrompt)
        """
    }

    /// メトリクスとユーザー情報をJSON文字列に変換する
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
            "request_variation_seed": Int.random(in: 1...100000) // 毎回ランダムな値を送り、回答の固定化を防ぐ
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: inputData, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }

    /// Gemini APIのレスポンスをパースしてDiagnosisReportに変換する
    /// - Parameter data: APIレスポンスの生データ
    /// - Returns: パース済みの診断レポート
    /// - Throws: JSONデコードエラーまたはレスポンス形式エラー
    /// - Note: Geminiのレスポンスからテキスト部分を抽出し、JSONとしてデコードします
    private func parseGeminiResponse(_ data: Data) throws -> DiagnosisReport {
        // Geminiのレスポンス構造に合わせてデコード
        struct GeminiResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable {
                        let text: String
                    }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]?
        }

        let geminiResp = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let text = geminiResp.candidates?.first?.content.parts.first?.text else {
            throw NSError(domain: "GeminiManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "レスポンスにコンテンツが含まれていません"])
        }

        // JSON文字列部分を抽出（Markdownのコードブロック ```json ... ``` が含まれる場合の対策）
        let jsonString = extractJsonString(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "GeminiManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to convert string to data"])
        }

        return try JSONDecoder().decode(DiagnosisReport.self, from: jsonData)
    }

    /// レスポンステキストからJSON文字列部分を抽出する
    /// - Parameter text: Gemini APIからのレスポンステキスト
    /// - Returns: JSON文字列
    /// - Note: Markdownのコードブロック ```json ... ``` が含まれる場合の対策
    private func extractJsonString(from text: String) -> String {
        // ```json と ``` の間、もしくは { と } の間を抽出する簡易ロジック
        if let rangeStart = text.range(of: "{"), let rangeEnd = text.range(of: "}", options: .backwards) {
            // 安全な範囲チェックを追加
            if rangeStart.lowerBound < rangeEnd.upperBound {
                return String(text[rangeStart.lowerBound..<rangeEnd.upperBound])
            }
        }
        return text
    }
}
/// コーチのペルソナ定義（言語ごとに独立）
/// v1.0: 6ペルソナ体制（Layer分離設計対応）
struct CoachPersona: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let themeColorHex: String
    let systemPrompt: String // V1互換用（V2ではFunctions側で管理）

    // デフォルトのペルソナ（優しいお姉さん）
    static var standard: CoachPersona {
        availablePersonas(for: LanguageManager.shared.currentLanguage).first!
    }

    /// 言語ごとの利用可能なペルソナリストを返す
    /// v1.0: 6ペルソナ（言語はAppStrings経由で取得）
    static func availablePersonas(for language: AppLanguage) -> [CoachPersona] {
        // ペルソナ定義（言語に依存しない部分）
        let personaConfigs: [(id: String, icon: String, themeColorHex: String)] = [
            ("gentle_sister", "👩", "FF2D55"),
            ("spartan", "🪖", "FF3B30"),
            ("standard", "🤖", "007AFF"),
            ("comedian", "🎤", "AF52DE"),
            ("gal", "💖", "FF9500"),
            ("toxic_pro", "🎯", "34C759")
        ]

        return personaConfigs.map { config in
            let nameKey = "coach_\(config.id)"
            let descKey = "desc_\(config.id)"
            let quoteKey = "quote_\(config.id)"

            // AppStrings経由で言語に応じた文字列を取得
            let name = LanguageManager.shared.localized(nameKey)
            let desc = LanguageManager.shared.localized(descKey)
            let quote = LanguageManager.shared.localized(quoteKey)

            return CoachPersona(
                id: config.id,
                name: name,
                description: "\(desc)\n\(quote)",
                icon: config.icon,
                themeColorHex: config.themeColorHex,
                systemPrompt: ""
            )
        }
    }

    // MARK: - Compatibility Properties (Static)
    // 旧CoachMode enumとの互換性のためにstaticプロパティを提供

    static var normal: CoachPersona {
        availablePersonas(for: LanguageManager.shared.currentLanguage).first { $0.id == "standard" } ?? standard
    }

    static var spartan: CoachPersona {
        availablePersonas(for: LanguageManager.shared.currentLanguage).first { $0.id == "spartan" } ?? standard
    }

    static var kind: CoachPersona {
        availablePersonas(for: LanguageManager.shared.currentLanguage).first { $0.id == "gentle_sister" } ?? standard
    }

    static var kansaiMom: CoachPersona {
        availablePersonas(for: LanguageManager.shared.currentLanguage).first { $0.id == "gal" } ?? standard
    }

    static var comedian: CoachPersona {
        availablePersonas(for: LanguageManager.shared.currentLanguage).first { $0.id == "comedian" } ?? standard
    }
}

// 互換性のためのエイリアス
typealias CoachMode = CoachPersona

