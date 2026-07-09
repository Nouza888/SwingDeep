import Foundation
import Combine

// MARK: - 利用回数制限

/// 利用回数制限を管理するシングルトン
///
/// ## 機能
/// - 月あたりの利用回数をカウント
/// - 成功時のみカウント（失敗時はカウントしない）
/// - 月が変わると自動リセット
/// - プランに応じた上限を適用
///
/// ## 制限（プラン別）
/// - Free: 月15回
/// - Standard: 月40回
/// - Premium: 無制限
///
/// ## 使用例
/// ```swift
/// // 生成可能かチェック
/// if UsageLimiter.shared.canGenerate {
///     // 生成処理
///     UsageLimiter.shared.recordSuccess()
/// }
///
/// // 残回数を確認
/// let remaining = UsageLimiter.shared.remainingCount
/// ```
class UsageLimiter: ObservableObject {

    // MARK: - Singleton

    static let shared = UsageLimiter()

    // MARK: - Constants

    /// UserDefaultsのキープレフィックス
    private let keyPrefix = "usage_count_"

    // MARK: - Published Properties

    /// 残り回数（UI Binding用）
    @Published private(set) var remainingCount: Int = 15

    // MARK: - Computed Properties

    /// 月あたりの利用上限（プランに応じて変動）
    var monthlyLimit: Int {
        let plan = SubscriptionManager.shared.currentPlan
        if plan.isUnlimited {
            return Int.max
        }
        return plan.monthlyLimit
    }

    /// 無制限プランかどうか
    var isUnlimited: Bool {
        SubscriptionManager.shared.currentPlan.isUnlimited
    }

    /// 今月の使用済み回数
    var usedCount: Int {
        currentMonthCount
    }

    /// UI表示用の残回数（常に最新のプランで計算）
    var displayRemainingCount: Int {
        if isUnlimited { return Int.max }
        return max(0, monthlyLimit - currentMonthCount)
    }

    /// 生成可能かどうか
    var canGenerate: Bool {
        isUnlimited || remainingCount > 0
    }

    // MARK: - Initialization

    private init() {
        refreshRemainingCount()
    }

    /// プラン変更時に呼び出す（残回数を再計算）
    func refreshForPlanChange() {
        refreshRemainingCount()
    }

    // MARK: - Public Methods

    /// 成功時に呼び出す（回数を加算）
    ///
    /// - Important: 必ずレポート生成成功後に呼び出すこと
    func recordSuccess() {
        currentMonthCount += 1
        refreshRemainingCount()
        objectWillChange.send()  // UI更新を確実にする
        logUsage()
    }

    /// 残回数を取得（最新値を確認）
    ///
    /// - Returns: 残り利用可能回数
    func checkRemainingCount() -> Int {
        refreshRemainingCount()
        return remainingCount
    }

    /// 制限に達しているか確認
    ///
    /// - Returns: 制限に達している場合はtrue
    func isLimitReached() -> Bool {
        // Premiumは常にfalse
        if isUnlimited { return false }

        refreshRemainingCount()
        return remainingCount <= 0
    }

    /// 次回リセット日（翌月1日）を取得
    ///
    /// - Returns: 次回リセット日時
    func getNextResetDate() -> Date {
        let calendar = Calendar.current
        let now = Date()

        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now),
              let firstDayOfNextMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) else {
            return now
        }

        return firstDayOfNextMonth
    }

    /// リセットまでの残り日数を取得
    ///
    /// - Returns: 残り日数
    func daysUntilReset() -> Int {
        let calendar = Calendar.current
        let resetDate = getNextResetDate()
        let components = calendar.dateComponents([.day], from: Date(), to: resetDate)
        return components.day ?? 0
    }

    // MARK: - Private Properties

    /// 現在月のカウント
    private var currentMonthCount: Int {
        get {
            let key = keyPrefix + currentMonthKey
            return UserDefaults.standard.integer(forKey: key)
        }
        set {
            let key = keyPrefix + currentMonthKey
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    /// 現在月のキー (YYYY-MM形式)
    private var currentMonthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    // MARK: - Private Methods

    /// 残回数を更新
    private func refreshRemainingCount() {
        // Premiumは無制限
        if isUnlimited {
            remainingCount = Int.max
            return
        }

        let used = currentMonthCount
        remainingCount = max(0, monthlyLimit - used)
    }

    /// 利用状況をログ出力
    private func logUsage() {
        print("📊 [UsageLimiter] Usage recorded. Remaining: \(remainingCount)")
    }
}
