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
struct SwingMetrics: Codable {
    /// 前傾角度の差分（マイナスは起き上がり）
    var spineAngleDiffDeg: Double
    
    /// 画面幅に対する腰の移動量
    var hipMoveRatio: Double
    
    /// 頭の上下動
    var headMoveY: Double
    
    /// Back : Down比率（テンポ）
    var tempoRatio: Double
    
    /// インパクトでの手の浮き上がり量
    var handRaiseY: Double
    
    /// スイング軌道タイプ ("Outside-In", "Inside-Out", "Straight")
    var swingPathType: String
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
    
    // JSON snake_case <-> Swift camelCase 変換
    enum CodingKeys: String, CodingKey {
        case coachComment = "coach_comment"
        case overallSummary = "overall_summary"
        case totalScore = "total_score"
        case swingRank = "swing_rank"
        case swingTypeName = "swing_type_name"
        case diagnosisItems = "diagnosis_items"
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
    
    /// ステータス ("Good", "Bad", "Check")
    var status: String
    
    /// 重要度 (1:軽微 〜 10:重度)
    var severity: Double
    
    /// 可視化用の値 (-100 〜 +100)
    var visualizationValue: Double
    
    /// コメント・アドバイス
    var comment: String
    
    /// 改善ドリル
    var drill: Drill?
    
    /// 改善ドリル詳細
    struct Drill: Codable, Equatable {
        var title: String
        var description: String
    }
    
    enum CodingKeys: String, CodingKey {
        case key
        case title
        case status
        case severity
        case visualizationValue = "visualization_value"
        case comment
        case drill
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
