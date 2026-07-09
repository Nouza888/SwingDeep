import SwiftUI
import SwiftData
import Foundation

// =============================================================================
// MARK: - 列挙型
// =============================================================================

/// ゴルファーの種別
enum UserType: String, Codable {
    case me      // 自分
    case friend  // 友人
    case pro     // プロ選手
}

// =============================================================================
// MARK: - 解析データ構造体
// =============================================================================

/// スイング解析の数値データ（LLMへの入力用）
/// - Note: MediaPipeの骨格データから計算された各種メトリクス
/// - Important: v2.0から相対評価（体格基準）に変更
struct SwingMetrics: Codable {
    /// 前傾角度の差分（耳-腰ベース、マイナスは起き上がり）
    var spineAngleDiffDeg: Double

    /// 腰の移動量（肩幅に対する比率、例: 0.1 = 肩幅の10%）
    var hipMoveRatio: Double

    /// 頭の上下動（身長に対する比率、例: 0.05 = 身長の5%）
    var headMoveY: Double

    /// Back : Down比率（テンポ）
    var tempoRatio: Double

    /// インパクトでの手の浮き上がり量（手〜頭距離に対する比率）
    var handRaiseY: Double

    /// スイング軌道タイプ ("Outside-In", "Inside-Out", "Straight")
    var swingPathType: String

    // MARK: - デバッグ用基準スケール（オプショナル）

    /// アドレス時の肩幅（正規化座標）
    var shoulderWidth: Double?

    /// アドレス時の手〜頭距離（正規化座標）
    var handToHeadDistance: Double?

    /// アドレス時の身長近似値（頭〜足首、正規化座標）
    var bodyHeight: Double?
}

// =============================================================================
// MARK: - 診断レポート構造体（API レスポンス用）
// =============================================================================

/// 診断レポート（LLMからの出力JSON）
/// - Important: SwiftDataで保存する際はJSONエンコードされたDataとして保存
struct DiagnosisReport: Codable, Equatable {
    var coachComment: String
    var overallSummary: String
    var totalScore: Int
    var swingRank: String
    var swingTypeName: String
    var diagnosisItems: [DiagnosisItem]

    // v1.0 レポート構成変更
    var drillsToShow: [String]
    var drillSectionMessage: String

    // JSON snake_case <-> Swift camelCase 変換
    enum CodingKeys: String, CodingKey {
        case coachComment = "coach_comment"
        case overallSummary = "overall_summary"
        case totalScore = "total_score"
        case swingRank = "swing_rank"
        case swingTypeName = "swing_type_name"
        case diagnosisItems = "diagnosis_items"
        case drillsToShow = "drills_to_show"
        case drillSectionMessage = "drill_section_message"
    }

    // Equatable準拠のための実装
    static func == (lhs: DiagnosisReport, rhs: DiagnosisReport) -> Bool {
        lhs.coachComment == rhs.coachComment &&
        lhs.totalScore == rhs.totalScore &&
        lhs.swingRank == rhs.swingRank
    }
}

/// 診断項目（個別の診断ポイント）
struct DiagnosisItem: Codable, Identifiable, Equatable {
    var id: String { key }

    /// 項目キー（swing_path, hand_position等）
    var key: String

    /// 表示タイトル
    var title: String

    /// 一言判定タイトル（LLM生成、例：「軸がブレブレです」）
    var judgmentTitle: String?

    /// 項目スコア（0-100、高いほど良い）
    /// - Note: オプショナルで既存データとの互換性維持
    var itemScore: Int?

    /// ステータス ("Good", "Bad", "Check")
    var status: String

    /// 重要度 (1:軽微 〜 10:重度)
    var severity: Double

    /// 可視化用の値 (-100 〜 +100)
    var visualizationValue: Double

    /// コメント・アドバイス
    var comment: String

    /// コメント内の強調フレーズ（UIで太字化する）
    var detailKeyPhrases: [String]

    /// v1.0: 要改善順Top2かどうか
    var isTop2: Bool

    /// 改善ドリル
    var drill: Drill?

    /// 改善ドリル詳細
    struct Drill: Codable, Equatable {
        var title: String
        var description: String

        /// ドリル説明内の強調フレーズ（UIで太字化する）
        var drillKeyPhrases: [String]

        // プール式ドリル詳細（v2.0追加）
        var drillId: String?
        var steps: [String]?
        var reps: String?
        var tools: [String]?
        var ng: [String]?
        var variantType: String?
        var timeSec: Int?

        enum CodingKeys: String, CodingKey {
            case title
            case description
            case drillKeyPhrases = "drill_key_phrases"
            case drillId = "drill_id"
            case steps = "drill_steps"
            case reps = "drill_reps"
            case tools = "drill_tools"
            case ng = "drill_ng"
            case variantType = "drill_variant_type"
            case timeSec = "drill_time_sec"
        }

        /// カスタムデコーダー（drillKeyPhrasesがない場合のデフォルト値設定）
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decode(String.self, forKey: .title)
            description = try container.decode(String.self, forKey: .description)
            drillKeyPhrases = try container.decodeIfPresent([String].self, forKey: .drillKeyPhrases) ?? []
            drillId = try container.decodeIfPresent(String.self, forKey: .drillId)
            steps = try container.decodeIfPresent([String].self, forKey: .steps)
            reps = try container.decodeIfPresent(String.self, forKey: .reps)
            tools = try container.decodeIfPresent([String].self, forKey: .tools)
            ng = try container.decodeIfPresent([String].self, forKey: .ng)
            variantType = try container.decodeIfPresent(String.self, forKey: .variantType)
            timeSec = try container.decodeIfPresent(Int.self, forKey: .timeSec)
        }

        /// 初期化（プログラム内で使用）
        init(title: String, description: String, drillKeyPhrases: [String] = [], drillId: String? = nil, steps: [String]? = nil, reps: String? = nil, tools: [String]? = nil, ng: [String]? = nil, variantType: String? = nil, timeSec: Int? = nil) {
            self.title = title
            self.description = description
            self.drillKeyPhrases = drillKeyPhrases
            self.drillId = drillId
            self.steps = steps
            self.reps = reps
            self.tools = tools
            self.ng = ng
            self.variantType = variantType
            self.timeSec = timeSec
        }
    }

    enum CodingKeys: String, CodingKey {
        case key
        case title
        case judgmentTitle = "judgment_title"
        case itemScore = "item_score"
        case status
        case severity
        case visualizationValue = "visualization_value"
        case comment
        case detailKeyPhrases = "detail_key_phrases"
        case isTop2 = "is_top2"
        case drill
    }

    /// カスタムデコーダー（detailKeyPhrasesがない場合のデフォルト値設定）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        title = try container.decode(String.self, forKey: .title)
        judgmentTitle = try container.decodeIfPresent(String.self, forKey: .judgmentTitle)
        itemScore = try container.decodeIfPresent(Int.self, forKey: .itemScore)
        status = try container.decode(String.self, forKey: .status)
        severity = try container.decode(Double.self, forKey: .severity)
        visualizationValue = try container.decode(Double.self, forKey: .visualizationValue)
        comment = try container.decode(String.self, forKey: .comment)
        detailKeyPhrases = try container.decodeIfPresent([String].self, forKey: .detailKeyPhrases) ?? []
        isTop2 = try container.decodeIfPresent(Bool.self, forKey: .isTop2) ?? false
        drill = try container.decodeIfPresent(Drill.self, forKey: .drill)
    }

    /// 初期化（プログラム内で使用）
    init(key: String, title: String, judgmentTitle: String? = nil, itemScore: Int? = nil, status: String, severity: Double, visualizationValue: Double, comment: String, detailKeyPhrases: [String] = [], isTop2: Bool = false, drill: Drill? = nil) {
        self.key = key
        self.title = title
        self.judgmentTitle = judgmentTitle
        self.itemScore = itemScore
        self.status = status
        self.severity = severity
        self.visualizationValue = visualizationValue
        self.comment = comment
        self.detailKeyPhrases = detailKeyPhrases
        self.isTop2 = isTop2
        self.drill = drill
    }
}

// =============================================================================
// MARK: - SwiftData モデル
// =============================================================================

/// ゴルファープロフィール（マルチユーザー対応）
@Model
class GolferProfile {
    var id: UUID
    var name: String
    var type: UserType

    /// プロフィールアイコン画像（大サイズのため外部ストレージ）
    @Attribute(.externalStorage) var icon: Data?

    /// このゴルファーの解析履歴
    @Relationship(deleteRule: .cascade) var analyses: [SwingAnalysis] = []

    init(id: UUID = UUID(), name: String, type: UserType, icon: Data? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.icon = icon
    }
}

/// スイング解析レコード
/// - Important: diagnosisReportは複雑なネスト構造のため、JSONエンコードしてDataとして保存
@Model
class SwingAnalysis {
    var id: UUID
    var date: Date

    /// 動画ファイルパス（Documentsディレクトリからの相対パス）
    var videoPath: String

    /// 動画の長さ
    var duration: TimeInterval

    // MARK: 診断用データ

    /// アドレス時刻（ミリ秒）
    var addressTime: Double

    /// インパクト時刻（ミリ秒）
    var impactTime: Double

    /// 解析メトリクス（JSONエンコードして保存）
    @Attribute(.externalStorage) var metricsData: Data?

    /// 診断レポート（JSONエンコードして保存）
    /// - Note: DiagnosisReportは複雑なネスト構造のため、Dataとして保存
    @Attribute(.externalStorage) var diagnosisReportData: Data?

    // MARK: リレーション

    /// 親プロフィールへの逆参照
    var golfer: GolferProfile?

    // MARK: 計算プロパティ

    /// メトリクス（エンコード/デコード）
    var metrics: SwingMetrics? {
        get {
            guard let data = metricsData else { return nil }
            return try? JSONDecoder().decode(SwingMetrics.self, from: data)
        }
        set {
            metricsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// 診断レポート（エンコード/デコード）
    var diagnosisReport: DiagnosisReport? {
        get {
            guard let data = diagnosisReportData else { return nil }
            return try? JSONDecoder().decode(DiagnosisReport.self, from: data)
        }
        set {
            diagnosisReportData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: イニシャライザ

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        videoPath: String,
        duration: TimeInterval,
        addressTime: Double,
        impactTime: Double,
        metrics: SwingMetrics? = nil,
        diagnosisReport: DiagnosisReport? = nil
    ) {
        self.id = id
        self.date = date
        self.videoPath = videoPath
        self.duration = duration
        self.addressTime = addressTime
        self.impactTime = impactTime
        self.metricsData = try? JSONEncoder().encode(metrics)
        self.diagnosisReportData = try? JSONEncoder().encode(diagnosisReport)
    }
}
