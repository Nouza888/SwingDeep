import Foundation

// MARK: - Report Context

/// レポートコンテキスト（ユーザーとの関係性フェーズ）
///
/// ## 概要
/// LLMの文言トーン・距離感・過去言及可否を制御するためのパラメータ。
/// severity/score/rankingには一切影響しない。
///
/// ## コンテキスト一覧
/// - `firstTime`: 初対面（信頼構築）
/// - `gettingUsed`: 2〜3回目（通ってる感）
/// - `regular`: 4回目以降（伴走者）
/// - `comeback`: 30日以上空いた（久しぶり）
enum ReportContext: String, Codable {
    case firstTime = "FIRST_TIME"
    case gettingUsed = "GETTING_USED"
    case regular = "REGULAR"
    case comeback = "COMEBACK"

    /// 日本語表示名
    var displayNameJa: String {
        switch self {
        case .firstTime: return "初回"
        case .gettingUsed: return "慣れ始め"
        case .regular: return "常連"
        case .comeback: return "復帰"
        }
    }
}

// MARK: - Report Context Manager

/// レポートコンテキストを管理するシングルトン
///
/// ## 機能
/// - レポート回数のカウント・永続化（UserDefaults）
/// - 最終レポート日時の記録
/// - report_context の決定
///
/// ## 判定ロジック
/// 1. reportCount == 0 → FIRST_TIME（最優先）
/// 2. 最終レポートから30日以上経過 → COMEBACK
/// 3. reportCount <= 2 → GETTING_USED
/// 4. それ以外 → REGULAR
class ReportContextManager {

    // MARK: - Singleton

    static let shared = ReportContextManager()

    // MARK: - Constants

    /// UserDefaultsキー：レポート回数
    private let reportCountKey = "report_count"

    /// UserDefaultsキー：最終レポート日時
    private let lastReportDateKey = "last_report_date"

    /// COMEBACK判定の閾値（日数）
    private let comebackThresholdDays = 30

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Properties

    /// 現在のレポート回数
    var reportCount: Int {
        return UserDefaults.standard.integer(forKey: reportCountKey)
    }

    /// 最終レポート日時
    var lastReportDate: Date? {
        return UserDefaults.standard.object(forKey: lastReportDateKey) as? Date
    }

    // MARK: - Public Methods

    /// レポートコンテキストを決定する
    ///
    /// ## 判定優先順位
    /// 1. FIRST_TIME: 初回（reportCount == 0）→ 最優先
    /// 2. COMEBACK: 30日以上経過
    /// 3. GETTING_USED: 2〜3回目（reportCount 1-2）
    /// 4. REGULAR: 4回目以降
    ///
    /// - Returns: 決定されたReportContext
    func determineContext() -> ReportContext {
        let count = reportCount

        // 1. 初回は最優先でFIRST_TIME
        if count == 0 {
            return .firstTime
        }

        // 2. 30日以上経過していたらCOMEBACK
        if isDueForComeback() {
            return .comeback
        }

        // 3. 2〜3回目はGETTING_USED
        if count <= 2 {
            return .gettingUsed
        }

        // 4. 4回目以降はREGULAR
        return .regular
    }

    /// レポート生成成功時に呼び出す（回数カウント + 日時記録）
    ///
    /// - Note: GeminiManagerのレポート生成成功後に呼び出してください
    func recordReportGenerated() {
        // 回数をインクリメント
        let newCount = reportCount + 1
        UserDefaults.standard.set(newCount, forKey: reportCountKey)

        // 最終レポート日時を更新
        UserDefaults.standard.set(Date(), forKey: lastReportDateKey)

        logContextUpdate(newCount: newCount)
    }

    /// 最終レポートからの経過日数を取得
    ///
    /// - Returns: 経過日数（レポート履歴がない場合は0）
    func daysSinceLastReport() -> Int {
        guard let lastDate = lastReportDate else {
            return 0
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: lastDate, to: Date())
        return components.day ?? 0
    }

    // MARK: - Private Methods

    /// COMEBACK判定
    private func isDueForComeback() -> Bool {
        let days = daysSinceLastReport()
        return days >= comebackThresholdDays
    }

    /// コンテキスト更新ログ
    private func logContextUpdate(newCount: Int) {
        let context = determineContext()
        print("📊 [ReportContextManager] Report recorded. Count: \(newCount), Context: \(context.rawValue)")
    }

    // MARK: - Debug Methods

    #if DEBUG
    /// デバッグ用：レポート回数をリセット
    func resetForDebug() {
        UserDefaults.standard.removeObject(forKey: reportCountKey)
        UserDefaults.standard.removeObject(forKey: lastReportDateKey)
        print("🔧 [ReportContextManager] Reset for debug")
    }

    /// デバッグ用：レポート回数を設定
    func setReportCountForDebug(_ count: Int) {
        UserDefaults.standard.set(count, forKey: reportCountKey)
        print("🔧 [ReportContextManager] Set count to \(count) for debug")
    }

    /// デバッグ用：最終レポート日時を設定
    func setLastReportDateForDebug(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastReportDateKey)
        print("🔧 [ReportContextManager] Set last report date for debug")
    }
    #endif
}
