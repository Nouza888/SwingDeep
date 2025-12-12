import Foundation

/// Gemini API通信時のエラー種別
enum GeminiError: LocalizedError {
    case invalidURL                    // URLが不正
    case networkError(Error)           // ネットワークエラー
    case invalidResponse(Int)          // HTTPステータスコードが200以外
    case parseError(String)            // JSONパース失敗
    case missingData                   // 必要なデータが不足
    case apiKeyMissing                 // APIキーが設定されていない
    
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
        case .apiKeyMissing:
            return "Gemini APIキーが設定されていません"
        }
    }
    
    /// リトライ可能なエラーかどうか
    var isRetryable: Bool {
        switch self {
        case .networkError, .invalidResponse:
            return true
        default:
            return false
        }
    }
}

/// Google Gemini APIとの通信を管理するクラス
///
/// Gemini 1.5 Flashモデルを使用して、スイング解析データから
/// 詳細な診断レポートを生成します。
///
/// ## 主な機能
/// - コーチペルソナに応じたプロンプト生成
/// - JSON形式での診断レポート取得
/// - ネットワークエラー時の自動リトライ
///
/// - Note: シングルトンパターンで実装されています
/// - Important: APIキーはAppConfig.swiftで管理されています
class GeminiManager {
    static let shared = GeminiManager()
    
    /// Gemini APIキー（Config.swiftから取得）
    private let apiKey: String = AppConfig.geminiApiKey
    
    /// Gemini APIのエンドポイントURL（モデル指定あり）
    private let baseURL: String = "\(AppConfig.geminiBaseURL)/\(AppConfig.geminiModel):generateContent"
    
    private init() {}
    
    // MARK: - Public Methods (公開メソッド)
    
    /// スイング解析データに基づいて診断レポートを生成する
    ///
    /// このメソッドは以下の処理を実行します：
    /// 1. APIキーの確認
    /// 2. システムプロンプトの構築（コーチペルソナ反映）
    /// 3. リクエストボディの作成
    /// 4. API呼び出し（リトライあり）
    /// 5. レスポンスのパースと検証
    ///
    /// - Parameters:
    ///   - metrics: 解析済みスイングメトリクス（背骨角度、腰の移動、頭の位置など）
    ///   - coachPersona: 選択されたコーチペルソナ（鬼軍曹、関西おかんなど）
    /// - Returns: 診断レポート（DiagnosisReport）
    /// - Throws: GeminiError - API通信またはパースに失敗した場合
    func generateDiagnosis(metrics: SwingMetrics, coachPersona: CoachPersona) async throws -> DiagnosisReport {
        // APIキーの確認
        guard !AppConfig.geminiApiKey.isEmpty else {
            throw GeminiError.apiKeyMissing
        }
        
        // リトライロジック付きAPI呼び出し
        return try await performAPICallWithRetry(
            metrics: metrics,
            coachPersona: coachPersona,
            maxRetries: 3
        )
    }
    
    // MARK: - Private Methods - API Communication (API通信)
    
    /// リトライロジック付きでAPI呼び出しを実行する
    ///
    /// ネットワークエラーや一時的なAPIエラーの場合、
    /// 指定された回数まで自動でリトライします。
    ///
    /// - Parameters:
    ///   - metrics: スイングメトリクス
    ///   - coachPersona: コーチペルソナ
    ///   - maxRetries: 最大リトライ回数（デフォルト: 3回）
    /// - Returns: 診断レポート
    /// - Throws: GeminiError
    private func performAPICallWithRetry(
        metrics: SwingMetrics,
        coachPersona: CoachPersona,
        maxRetries: Int = 3
    ) async throws -> DiagnosisReport {
        var lastError: GeminiError?
        
        for attempt in 1...maxRetries {
            do {
                // API呼び出しを試行
                return try await executeDiagnosisAPI(
                    metrics: metrics,
                    coachPersona: coachPersona
                )
            } catch let error as GeminiError {
                lastError = error
                
                // リトライ不可なエラーの場合は即座にスロー
                if !error.isRetryable {
                    print("❌ [GeminiManager] リトライ不可エラー: \(error.localizedDescription)")
                    throw error
                }
                
                // 最後の試行でなければ、少し待ってからリトライ
                if attempt < maxRetries {
                    let delay = Double(attempt) * 1.0  // 1秒、 2秒、 3秒...
                    print("⚠️ [GeminiManager] リトライ \(attempt)/\(maxRetries): \(delay)秒後に再試行")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                // GeminiError以外のエラー
                throw GeminiError.networkError(error)
            }
        }
        
        // 全てのリトライが失敗した場合
        print("❌ [GeminiManager] \(maxRetries)回のリトライ後も失敗")
        throw lastError ?? GeminiError.networkError(NSError(domain: "Unknown", code: -1))
    }
    
    /// Gemini APIに診断リクエストを送信する（実際のAPI呼び出し）
    ///
    /// - Parameters:
    ///   - metrics: スイングメトリクス
    ///   - coachPersona: コーチペルソナ
    /// - Returns: 診断レポート
    /// - Throws: GeminiError
    private func executeDiagnosisAPI(
        metrics: SwingMetrics,
        coachPersona: CoachPersona
    ) async throws -> DiagnosisReport {
        let apiKey = AppConfig.geminiApiKey
        let urlString = "\(AppConfig.geminiBaseURL)/\(AppConfig.geminiModel):generateContent?key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }
        
        // システムプロンプトの構築
        let systemInstruction = constructSystemInstruction(coachPersona: coachPersona)
        
        // ユーザー入力データの構築
        let inputJson = constructInputJson(metrics: metrics, userProfile: [:])
        let userPrompt = "以下のスイング解析データを診断してください：\n\(inputJson)"
        
        // リクエストボディの作成
        let requestBody = buildRequestBody(
            systemInstruction: systemInstruction,
            userPrompt: userPrompt
        )
        
        // HTTPリクエストの設定
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60  // 60秒タイムアウト
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // デバッグログ
        logAPIRequest(url: urlString, body: request.httpBody)
        
        // APIリクエスト実行
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // デバッグログ
        logAPIResponse(response: response, data: data)
        
        // レスポンスのステータスコード確認
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse(0)
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "不明なエラー"
            print("🔴 [GeminiManager] APIエラー: \(errorMsg)")
            throw GeminiError.invalidResponse(httpResponse.statusCode)
        }
        
        // レスポンスのパース
        return try parseGeminiResponse(data)
    }
    
    // MARK: - Private Methods - Helpers (ヘルパーメソッド)
    
    /// APIリクエストボディを構築する
    ///
    /// Gemini APIのリクエスト形式に従ってJSONボディを生成します。
    ///
    /// - Parameters:
    ///   - systemInstruction: システムプロンプト文字列
    ///   - userPrompt: ユーザープロンプト文字列
    /// - Returns: リクエストボディの辞書
    private func buildRequestBody(
        systemInstruction: String,
        userPrompt: String
    ) -> [String: Any] {
        return [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": userPrompt]
                    ]
                ]
            ],
            "systemInstruction": [
                "parts": [
                    ["text": systemInstruction]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]
    }
    
    /// APIリクエストのログを出力する（デバッグ用）
    ///
    /// - Parameters:
    ///   - url: リクエストURL
    ///   - body: リクエストボディ
    private func logAPIRequest(url: String, body: Data?) {
        guard AppConfig.isDebugMode else { return }
        
        print("🔵 [GeminiManager] API Request URL: \(url)")
        print("🔵 [GeminiManager] Model: \(AppConfig.geminiModel)")
        
        if let body = body, let bodyString = String(data: body, encoding: .utf8) {
            print("🔵 [GeminiManager] Request Body (first 500 chars): \(String(bodyString.prefix(500)))")
        }
    }
    
    /// APIレスポンスのログを出力する（デバッグ用）
    ///
    /// - Parameters:
    ///   - response: URLResponse
    ///   - data: レスポンスデータ
    private func logAPIResponse(response: URLResponse, data: Data) {
        guard AppConfig.isDebugMode else { return }
        
        print("🟢 [GeminiManager] Response received")
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🟢 [GeminiManager] Status Code: \(httpResponse.statusCode)")
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("🟢 [GeminiManager] Response Body (first 1000 chars): \(String(responseString.prefix(1000)))")
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
struct CoachPersona: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let themeColorHex: String // 16進数カラーコード
    let systemPrompt: String // ペルソナ固有のシステムプロンプト指示
    
    // デフォルトのペルソナ（標準）
    static var standard: CoachPersona {
        availablePersonas(for: LanguageManager.shared.currentLanguage).first!
    }
    
    /// 言語ごとの利用可能なペルソナリストを返す
    static func availablePersonas(for language: AppLanguage) -> [CoachPersona] {
        switch language {
        case .japanese:
            return [
                CoachPersona(
                    id: "normal_jp",
                    name: "標準",
                    description: "データに基づいた冷静かつ論理的な分析を行います。",
                    icon: "🤖",
                    themeColorHex: "007AFF", // Blue
                    systemPrompt: "あなたはプロのゴルフコーチです。データに基づき、論理的かつ冷静に分析結果を伝えてください。敬語を使い、簡潔で分かりやすい説明を心がけてください。"
                ),
                CoachPersona(
                    id: "spartan_jp",
                    name: "鬼軍曹",
                    description: "甘えを許さない厳しい指導で、徹底的に鍛え上げます。",
                    icon: "👹",
                    themeColorHex: "FF3B30", // Red
                    systemPrompt: "あなたは非常に厳しいスパルタゴルフコーチ「鬼軍曹」です。ユーザーを「貴様」や「お前」と呼び、甘えを一切許さない口調で指導してください。ただし、アドバイスは的確で、上達への情熱は人一倍あります。「気合が足りん！」「歯を食いしばれ！」などのフレーズを多用してください。"
                ),
                CoachPersona(
                    id: "kind_jp",
                    name: "お姉さん",
                    description: "優しく褒めて伸ばすスタイル。初心者の方におすすめです。",
                    icon: "👩",
                    themeColorHex: "FF2D55", // Pink
                    systemPrompt: "あなたは優しくて包容力のあるお姉さんコーチです。ユーザーを「くん」や「ちゃん」付けで呼び、とにかく褒めて伸ばすスタイルです。「すごい！」「惜しい！」など感情豊かに、絵文字も多用して励ましてください。"
                ),
                CoachPersona(
                    id: "kansai_mom_jp",
                    name: "関西おかん",
                    description: "愛のあるツッコミとお節介で、親身にアドバイスします。",
                    icon: "🐯",
                    themeColorHex: "FF9500", // Orange
                    systemPrompt: "あなたは世話焼きな「関西のおかん」です。コテコテの関西弁で話し、「あんた」「〜やんか」「飴ちゃんあげるわ」などのフレーズを使ってください。親しみやすく、時に厳しく、愛のあるツッコミを入れてください。"
                ),
                CoachPersona(
                    id: "comedian_jp",
                    name: "芸人",
                    description: "ユニークな例え話で、楽しみながらスイング改善できます。",
                    icon: "🎤",
                    themeColorHex: "AF52DE", // Purple
                    systemPrompt: "あなたは人気のお笑い芸人コーチです。スイングの欠点を、誰もが笑ってしまうようなユニークな例え話（「カマキリの求愛ダンスか！」など）で指摘してください。ユーモアたっぷりに、でも核心を突いたアドバイスをしてください。"
                )
            ]
            
        case .english:
            return [
                CoachPersona(
                    id: "standard_en",
                    name: "Standard",
                    description: "Provides calm, logical analysis based on data.",
                    icon: "🤖",
                    themeColorHex: "007AFF", // Blue
                    systemPrompt: "You are a professional golf coach. Provide logical and calm analysis based on data. Use polite language and ensure explanations are concise and easy to understand."
                ),
                CoachPersona(
                    id: "sergeant_en",
                    name: "Drill Sergeant",
                    description: "Strict guidance with no excuses. Toughens you up.",
                    icon: "🪖",
                    themeColorHex: "FF3B30", // Red
                    systemPrompt: "You are a strict Drill Sergeant golf coach. Call the user 'Private' or 'Maggot'. Do not tolerate any excuses. Your tone is aggressive and commanding. Use phrases like 'Drop and give me 20!' or 'Is that all you got?'. However, your advice is accurate and aims to toughen them up."
                ),
                CoachPersona(
                    id: "sister_en",
                    name: "Supportive Sister",
                    description: "Praises and encourages. Recommended for beginners.",
                    icon: "👩",
                    themeColorHex: "FF2D55", // Pink
                    systemPrompt: "You are a supportive and kind older sister figure. Call the user 'Sweetie' or 'Champ'. Focus on positive reinforcement. Use lots of encouraging words like 'Great job!', 'You're doing amazing!', and use emojis. Be very gentle with criticism."
                ),
                CoachPersona(
                    id: "hero_en",
                    name: "Hollywood Hero",
                    description: "Dramatic and inspiring feedback like a movie star.",
                    icon: "🎬",
                    themeColorHex: "FF9500", // Orange
                    systemPrompt: "You are a dramatic Hollywood Action Hero. Speak in epic, movie-trailer voice. Use metaphors about saving the world or defusing bombs. 'This swing is a ticking time bomb!' or 'You're the chosen one!'. Be over-the-top, inspiring, and intense."
                ),
                CoachPersona(
                    id: "butler_en",
                    name: "British Butler",
                    description: "Polite, dry wit, and sophisticated advice.",
                    icon: "☕️",
                    themeColorHex: "AF52DE", // Purple
                    systemPrompt: "You are a sophisticated British Butler. Speak with extreme politeness and dry wit. Address the user as 'Sir' or 'Madam'. Use phrases like 'If I may suggest...' or 'A trifle untidy, I'm afraid'. Be elegant, refined, and slightly sarcastic but helpful."
                )
            ]
        }
    }

    
    // MARK: - Compatibility Properties (Static)
    // 旧CoachMode enumとの互換性のためにstaticプロパティを提供
    
    static var normal: CoachPersona {
        availablePersonas(for: LanguageManager.shared.currentLanguage).first { $0.id.contains("normal") || $0.id.contains("standard") } ?? standard
    }
    
    static var spartan: CoachPersona {
        availablePersonas(for: LanguageManager.shared.currentLanguage).first { $0.id.contains("spartan") || $0.id.contains("sergeant") } ?? standard
    }
    
    static var kind: CoachPersona {
        availablePersonas(for: LanguageManager.shared.currentLanguage).first { $0.id.contains("kind") || $0.id.contains("sister") } ?? standard
    }
    
    static var kansaiMom: CoachPersona {
        availablePersonas(for: LanguageManager.shared.currentLanguage).first { $0.id.contains("kansai") || $0.id.contains("hero") } ?? standard
    }
    
    static var comedian: CoachPersona {
        availablePersonas(for: LanguageManager.shared.currentLanguage).first { $0.id.contains("comedian") || $0.id.contains("butler") } ?? standard
    }
}

// 互換性のためのエイリアス（必要に応じて削除可能）
typealias CoachMode = CoachPersona
