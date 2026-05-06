import Foundation
import SwiftData

// MARK: - スイングメトリクス

/// スイング解析の数値データ
///
/// v2.0: 胴体長比ベース
/// - headMoveY: 胴体長に対する比率
/// - hipMoveRatio: 胴体長に対する比率
/// - handRaiseY: 胴体長に対する比率
/// - spineAngleDiffDeg: 耳-腰ベースの角度差（度）
struct SwingMetrics: Codable {
    let spineAngleDiffDeg: Double  // 前傾角度差（度）- 耳-腰ベース
    let hipMoveRatio: Double       // 腰の移動量（胴体長比）
    let headMoveY: Double          // 頭の上下動（胴体長比）
    let tempoRatio: Double         // テンポ比率
    let handRaiseY: Double         // 手の浮き（胴体長比）
    let swingPathType: String      // スイング軌道タイプ
    
    /// 空のメトリクス（デフォルト値）
    static var empty: SwingMetrics {
        SwingMetrics(
            spineAngleDiffDeg: 0,
            hipMoveRatio: 0,
            headMoveY: 0,
            tempoRatio: 3.0,
            handRaiseY: 0,
            swingPathType: "Unknown"
        )
    }
}

// MARK: - 診断レポート

/// AI診断レポート（JSON出力フォーマット）
struct DiagnosisReport: Codable {
    let coachComment: String
    let overallSummary: String
    let totalScore: Int
    let swingRank: String
    let swingTypeName: String
    let diagnosisItems: [DiagnosisItem]
    let drillsToShow: [String]
    let drillSectionMessage: String
    
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
}

/// 診断項目
struct DiagnosisItem: Codable, Identifiable {
    let key: String
    let title: String
    let judgmentTitle: String?     // 一言判定タイトル（7〜14文字）
    let itemScore: Int?            // 項目スコア（0-100）
    let status: String
    let severity: Double
    let visualizationValue: Double
    let comment: String
    let detailKeyPhrases: [String] // キーフレーズ（太字化用）
    let isTop2: Bool               // 上位2件フラグ（ドリル表示判定用）
    let drill: Drill?
    
    var id: String { key }
    
    enum CodingKeys: String, CodingKey {
        case key, title, status, severity, comment, drill
        case judgmentTitle = "judgment_title"
        case itemScore = "item_score"
        case visualizationValue = "visualization_value"
        case detailKeyPhrases = "detail_key_phrases"
        case isTop2 = "is_top2"
    }
    
    /// ドリルデータ
    struct Drill: Codable {
        let title: String
        let description: String
        let drillKeyPhrases: [String]
        let steps: [String]?
        let reps: String?
        let tools: [String]?
        let ng: [String]?
        let timeSec: Int?
        
        enum CodingKeys: String, CodingKey {
            case title, description, steps, reps, tools, ng
            case drillKeyPhrases = "drill_key_phrases"
            case timeSec = "time_sec"
        }
    }
}

// MARK: - SwiftData Model

/// スイング解析結果のSwiftDataモデル（永続化用）
@Model
final class SwingAnalysis {
    var date: Date
    var videoPath: String
    var duration: Double
    var addressTime: Double
    var impactTime: Double
    
    // JSON形式で保存
    var metricsData: Data?
    var reportData: Data?
    
    // Computed Properties
    var metrics: SwingMetrics? {
        guard let data = metricsData else { return nil }
        return try? JSONDecoder().decode(SwingMetrics.self, from: data)
    }
    
    var diagnosisReport: DiagnosisReport? {
        guard let data = reportData else { return nil }
        return try? JSONDecoder().decode(DiagnosisReport.self, from: data)
    }
    
    init(date: Date, videoPath: String, duration: Double, addressTime: Double, impactTime: Double, metrics: SwingMetrics?, diagnosisReport: DiagnosisReport?) {
        self.date = date
        self.videoPath = videoPath
        self.duration = duration
        self.addressTime = addressTime
        self.impactTime = impactTime
        self.metricsData = try? JSONEncoder().encode(metrics)
        self.reportData = try? JSONEncoder().encode(diagnosisReport)
    }
}
