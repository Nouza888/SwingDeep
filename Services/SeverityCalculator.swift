import Foundation

// MARK: - Severity Types

/// スウィング項目の重要度
enum Severity: String, Codable {
    case good = "good"
    case ok = "ok"
    case bad = "bad"
}

/// メタモード（UX制御用）
enum MetaMode: String {
    case excellent = "EXCELLENT"       // 全項目good
    case almostThere = "ALMOST_THERE"  // 5項目good + 1項目惜しい
    case rebuild = "REBUILD"           // 4項目以上bad
    case normal = "NORMAL"             // 通常
}

/// メトリクスキー
enum MetricKey: String, CaseIterable, Codable {
    case spineAngle = "spine_angle"       // 前傾キープ
    case tempo = "tempo"                   // 切り返しリズム
    case swingPath = "swing_path"          // スイング軌道
    case headMovement = "head_movement"    // 頭の安定感
    case handPosition = "hand_position"    // インパクト時の手元
    case earlyExtension = "early_extension" // 腰の伸び上がり

    /// 日本語表示名（刷新版）
    var displayNameJa: String {
        switch self {
        case .spineAngle: return "前傾キープ"
        case .tempo: return "切り返しリズム"
        case .swingPath: return "スイング軌道"
        case .headMovement: return "頭の安定感"
        case .handPosition: return "インパクト時の手元"
        case .earlyExtension: return "腰の伸び上がり"
        }
    }

    /// 英語表示名
    var displayNameEn: String {
        switch self {
        case .spineAngle: return "Spine Angle"
        case .tempo: return "Transition Timing"
        case .swingPath: return "Swing Path"
        case .headMovement: return "Head Stability"
        case .handPosition: return "Hand Position"
        case .earlyExtension: return "Hip Extension"
        }
    }

    func displayName(for language: AppLanguage) -> String {
        switch language {
        case .japanese: return displayNameJa
        case .english: return displayNameEn
        }
    }
}

// MARK: - Ranked Item

/// V2リクエスト用の項目データ
struct ItemRanked: Codable {
    let key: MetricKey
    let displayName: String
    let severity: Severity
    let metrics: [String: Double]
    let itemScore: Int  // 内部スコア（0-100）

    enum CodingKeys: String, CodingKey {
        case key
        case displayName = "display_name"
        case severity
        case metrics
        case itemScore = "item_score"
    }

    /// severityと正規化されたdeviation（0〜1）から内部スコアを計算
    /// 推奨式: score = upper - width * d（dは0〜1）
    /// スコアが極端にならないよう、deviationを0.1〜0.9の範囲にスケーリング
    /// - good: 97 - 22d → 75〜97
    /// - ok: 72 - 25d → 47〜72
    /// - bad: 42 - 37d → 5〜42
    /// - Parameter normalizedDeviation: 0〜1に正規化された逸脱量（nilならデフォルト0.5を使用）
    static func calculateItemScore(from severity: Severity, normalizedDeviation: Double? = nil) -> Int {
        // 正規化されたdeviation（0〜1にクランプ）
        let rawD = min(1.0, max(0.0, normalizedDeviation ?? 0.5))
        // 0.1〜0.9の範囲にスケーリング（極端な0/100を避ける）
        let d = 0.1 + rawD * 0.8

        let score: Double
        switch severity {
        case .good:
            // 97 - 22 * d → 約75〜97の範囲
            score = 97.0 - 22.0 * d
        case .ok:
            // 72 - 25 * d → 約47〜72の範囲
            score = 72.0 - 25.0 * d
        case .bad:
            // 42 - 37 * d → 約5〜42の範囲
            score = 42.0 - 37.0 * d
        }

        // 帯内クランプ保証
        return Int(max(0, min(100, score.rounded())))
    }
}

// MARK: - Severity Calculator

/// Severity判定を行う計算機
/// v1.0 ゴールドスタンダード（全ペルソナ共通・固定）
struct SeverityCalculator {

    /// Severity閾値定義
    private struct Thresholds {
        let goodMax: Double
        let okMax: Double
    }

    /// 各項目の閾値テーブル（v2.0: 胴体長比ベース）
    /// - Note: 全て胴体長に対する比率（0.1 = 10%）または角度（度）
    private static let thresholds: [MetricKey: Thresholds] = [
        .spineAngle: Thresholds(goodMax: 3.0, okMax: 6.0),         // 度（耳-腰ベース）
        .tempo: Thresholds(goodMax: 0.0, okMax: 0.0),              // 特殊処理
        .swingPath: Thresholds(goodMax: 3.0, okMax: 7.0),          // 度（維持）
        .headMovement: Thresholds(goodMax: 0.10, okMax: 0.20),     // 胴体長比 10%/20%
        .handPosition: Thresholds(goodMax: 0.10, okMax: 0.20),     // 胴体長比 10%/20%
        .earlyExtension: Thresholds(goodMax: 0.10, okMax: 0.20),   // 胴体長比 10%/20%
    ]

    /// 単一項目のseverityを計算
    static func calculate(_ key: MetricKey, value: Double) -> Severity {
        // テンポは範囲判定
        if key == .tempo {
            if value >= 2.6 && value <= 3.2 {
                return .good
            } else if value >= 2.2 && value <= 3.6 {
                return .ok
            } else {
                return .bad
            }
        }

        // 他の項目は絶対値で判定
        guard let threshold = thresholds[key] else { return .ok }
        let absValue = abs(value)

        if absValue <= threshold.goodMax {
            return .good
        } else if absValue <= threshold.okMax {
            return .ok
        } else {
            return .bad
        }
    }

    /// SwingMetricsから全項目のseverityを計算し、危険度順にソート
    static func calculateAll(from metrics: SwingMetrics, language: AppLanguage) -> [ItemRanked] {
        // 各項目の値とseverityを計算
        var items: [(key: MetricKey, value: Double, severity: Severity)] = []

        // 1. Swing Path - swingPathTypeから推定値を生成
        let swingPathValue: Double = {
            switch metrics.swingPathType {
            case "Outside-In": return 8.0   // カット軌道
            case "Inside-Out": return -8.0  // インサイドアウト
            case "Straight": return 0.0
            default: return 5.0
            }
        }()
        let swingPathSeverity = calculate(.swingPath, value: swingPathValue)
        items.append((key: .swingPath, value: swingPathValue, severity: swingPathSeverity))

        // 2. Spine Angle（前傾キープ）- 耳-腰ベース
        let spineAngleSeverity = calculate(.spineAngle, value: metrics.spineAngleDiffDeg)
        items.append((key: .spineAngle, value: metrics.spineAngleDiffDeg, severity: spineAngleSeverity))

        // 3. Early Extension（腰の伸び上がり）- 胴体長比
        let earlyExtSeverity = calculate(.earlyExtension, value: metrics.hipMoveRatio)
        items.append((key: .earlyExtension, value: metrics.hipMoveRatio, severity: earlyExtSeverity))

        // 4. Head Movement（頭の安定感）- 胴体長比
        let headSeverity = calculate(.headMovement, value: metrics.headMoveY)
        items.append((key: .headMovement, value: metrics.headMoveY, severity: headSeverity))

        // 5. Hand Position（インパクト時の手元）- 胴体長比
        let handPosSeverity = calculate(.handPosition, value: metrics.handRaiseY)
        items.append((key: .handPosition, value: metrics.handRaiseY, severity: handPosSeverity))

        // 6. Tempo（切り返しリズム）
        let tempoSeverity = calculate(.tempo, value: metrics.tempoRatio)
        items.append((key: .tempo, value: metrics.tempoRatio, severity: tempoSeverity))

        // 危険度順にソート（bad > ok > good）
        let sorted = items.sorted { lhs, rhs in
            let lhsScore = severityScore(lhs.severity)
            let rhsScore = severityScore(rhs.severity)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            // 同じseverityなら値の絶対値が大きい方を優先
            return abs(lhs.value) > abs(rhs.value)
        }

        // ItemRankedに変換（正規化されたdeviationでitemScore計算）
        return sorted.map { item in
            let normalizedDev = normalizeDeviation(key: item.key, value: item.value, severity: item.severity)
            let score = ItemRanked.calculateItemScore(from: item.severity, normalizedDeviation: normalizedDev)
            return ItemRanked(
                key: item.key,
                displayName: item.key.displayName(for: language),
                severity: item.severity,
                metrics: [item.key.rawValue: item.value],
                itemScore: score
            )
        }
    }

    /// 逸脱量を0〜1に正規化（severity帯内での相対位置）
    /// - Parameters:
    ///   - key: メトリクスキー
    ///   - value: 実測値
    ///   - severity: 判定されたseverity
    /// - Returns: 0〜1の正規化された逸脱量（0が最良、1が帯内最悪）
    private static func normalizeDeviation(key: MetricKey, value: Double, severity: Severity) -> Double {
        guard let threshold = thresholds[key] else {
            // テンポは特殊処理
            if key == .tempo {
                return normalizeTempoDeviation(value: value, severity: severity)
            }
            return 0.5 // デフォルト中間値
        }

        let absValue = abs(value)

        switch severity {
        case .good:
            // 0〜goodMax の範囲で正規化
            return min(1.0, absValue / max(0.01, threshold.goodMax))
        case .ok:
            // goodMax〜okMax の範囲で正規化
            let range = threshold.okMax - threshold.goodMax
            let position = absValue - threshold.goodMax
            return min(1.0, max(0.0, position / max(0.01, range)))
        case .bad:
            // okMax以上の範囲で正規化（okMaxの2倍を1.0とする）
            let badMax = threshold.okMax * 2
            let position = absValue - threshold.okMax
            let range = badMax - threshold.okMax
            return min(1.0, max(0.0, position / max(0.01, range)))
        }
    }

    /// テンポの正規化（範囲判定のため特殊処理）
    private static func normalizeTempoDeviation(value: Double, severity: Severity) -> Double {
        let idealCenter = 2.9 // 理想値の中心
        let deviation = abs(value - idealCenter)

        switch severity {
        case .good:
            // 2.6〜3.2 の範囲（中心からの距離で正規化）
            return min(1.0, deviation / 0.3)
        case .ok:
            // 2.2〜2.6 または 3.2〜3.6 の範囲
            return min(1.0, max(0.0, (deviation - 0.3) / 0.4))
        case .bad:
            // それ以外
            return min(1.0, max(0.0, (deviation - 0.7) / 0.7))
        }
    }

    /// severityの危険度スコア（ソート用）
    private static func severityScore(_ severity: Severity) -> Int {
        switch severity {
        case .bad: return 3
        case .ok: return 2
        case .good: return 1
        }
    }
}

// MARK: - Meta Mode Calculator

/// MetaModeを計算
struct MetaModeCalculator {
    static func calculate(from items: [ItemRanked]) -> MetaMode {
        let goodCount = items.filter { $0.severity == .good }.count
        let badCount = items.filter { $0.severity == .bad }.count

        if goodCount == 6 {
            return .excellent
        } else if goodCount == 5 {
            return .almostThere
        } else if badCount >= 4 {
            return .rebuild
        } else {
            return .normal
        }
    }
}

// MARK: - Score Calculator

/// 総合スコア計算（0-100点）
/// - v2.0: 重み付き平均 + 致命傷ペナルティ方式
struct ScoreCalculator {

    /// 各項目の重み（ゴルフ的な影響度に基づく）
    /// - 軌道: 球筋と再現性に直結
    /// - 前傾・腰: スイングの土台
    /// - テンポ: 安定性に効く
    /// - 手・頭: 症状として表れやすく、上位改善で連鎖的に改善
    private static let weights: [MetricKey: Double] = [
        .swingPath: 1.25,       // スイング軌道
        .spineAngle: 1.20,      // 前傾角度
        .earlyExtension: 1.15,  // 腰の移動量
        .tempo: 1.00,           // スイングテンポ
        .handPosition: 0.85,    // インパクト時の手の浮き
        .headMovement: 0.75     // 頭の上下動
    ]

    /// 致命傷ペナルティの閾値
    private static let penaltyThreshold: Double = 55.0
    private static let penaltyMultiplier: Double = 0.2
    private static let maxPenalty: Double = 8.0

    /// 総合スコアを計算
    /// - Parameter items: 各項目のItemRanked（itemScoreを含む）
    /// - Returns: 0-100の総合スコア
    static func calculate(from items: [ItemRanked]) -> Int {
        // (1) 各項目のスコアと重みを収集
        var weightedSum: Double = 0
        var totalWeight: Double = 0
        var scores: [Double] = []

        for item in items {
            let score = item.itemScore
            let clampedScore = Double(max(0, min(100, score)))
            let weight = weights[item.key] ?? 1.0

            weightedSum += weight * clampedScore
            totalWeight += weight
            scores.append(clampedScore)
        }

        // スコアがない場合はフォールバック
        guard totalWeight > 0 else {
            return calculateFallback(from: items)
        }

        // (2) 重み付き平均を計算
        let baseScore = weightedSum / totalWeight

        // (3) 致命傷ペナルティを計算
        let minScore = scores.min() ?? 100
        let penalty: Double
        if minScore >= penaltyThreshold {
            penalty = 0
        } else {
            penalty = min(maxPenalty, (penaltyThreshold - minScore) * penaltyMultiplier)
        }

        // (4) 最終スコアを算出
        let finalScore = baseScore - penalty
        return max(0, min(100, Int(finalScore.rounded())))
    }

    /// フォールバック: itemScoreがない場合のseverityベース計算
    private static func calculateFallback(from items: [ItemRanked]) -> Int {
        var score: Double = 0
        for item in items {
            switch item.severity {
            case .good: score += 16.67
            case .ok: score += 10.0
            case .bad: score += 5.0
            }
        }
        return min(100, max(0, Int(score.rounded())))
    }
}

// MARK: - Diagnosis Report V2

/// V2診断レポート
struct DiagnosisReportV2 {
    let overallBadgeTitle: String
    let overallCardText: String
    let score: Int
    let metaMode: MetaMode
    let details: [DetailItemV2]
    let itemsRanked: [ItemRanked]

    /// 表示用：詳細項目を順番に取得
    func getDetail(for key: MetricKey) -> DetailItemV2? {
        return details.first { $0.key == key.rawValue }
    }

    /// 表示用：特定項目のItemRankedを取得
    func getItemRanked(for key: MetricKey) -> ItemRanked? {
        return itemsRanked.first { $0.key == key }
    }

    /// V1型への変換（既存のDiagnosisView互換）
    func toDiagnosisReport() -> DiagnosisReport {
        // details を DiagnosisItem に変換
        // indexを使ってitemsRankedと対応付け（detailsとitemsRankedは同じ順序のはず）
        let diagnosisItems = details.enumerated().map { (index, detail) -> DiagnosisItem in
            // indexでitemsRankedを取得（より確実）
            let itemRanked = index < itemsRanked.count ? itemsRanked[index] : nil
            let severity = itemRanked?.severity ?? .ok
            let severityValue: Double = severity == .bad ? 8.0 : severity == .ok ? 5.0 : 2.0

            // keyはitemsRankedから取得（MetricKeyのrawValue = "spine_angle"など）
            // detail.keyが不正な場合のフォールバックも用意
            let itemKey = itemRanked?.key.rawValue ?? detail.key

            return DiagnosisItem(
                key: itemKey,  // itemsRankedから確実に取得
                title: itemRanked?.displayName ?? detail.key,
                judgmentTitle: detail.judgmentTitle,  // LLM生成の一言判定タイトル
                itemScore: itemRanked?.itemScore,     // 項目スコア（0-100）
                status: severity == .bad ? "Bad" : severity == .ok ? "Check" : "Good",
                severity: severityValue,
                visualizationValue: 0,
                comment: detail.detailText,
                detailKeyPhrases: [],  // API側で設定されるが、ローカルでは空
                isTop2: index < 2,  // v1.0: 上位2件をTop2とする（暫定）
                drill: DiagnosisItem.Drill(
                    title: detail.drillTitle,
                    description: detail.drillText,
                    drillKeyPhrases: []  // API側で設定されるが、ローカルでは空
                )
            )
        }

        // v1.0: ドリル表示対象を計算
        let badCheckItems = diagnosisItems.filter { $0.status == "Bad" || $0.status == "Check" }
        let drillsToShow: [String]
        if badCheckItems.count >= 2 {
            drillsToShow = diagnosisItems.filter { $0.isTop2 }.map { $0.key }
        } else if badCheckItems.count == 1 {
            drillsToShow = [badCheckItems[0].key]
        } else {
            drillsToShow = []
        }

        return DiagnosisReport(
            coachComment: "",
            overallSummary: overallCardText,
            totalScore: score,
            swingRank: metaMode.rawValue,
            swingTypeName: overallBadgeTitle,
            diagnosisItems: diagnosisItems,
            drillsToShow: drillsToShow,
            drillSectionMessage: ""  // API側で設定されるが、ローカルでは空
        )
    }
}
