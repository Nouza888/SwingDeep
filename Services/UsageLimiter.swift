import Foundation
import Combine

class UsageLimiter: ObservableObject {
    static let shared = UsageLimiter()
    private let keyPrefix = "usage_count_"
    @Published private(set) var remainingCount: Int = 15
    
    var monthlyLimit: Int {
        let plan = SubscriptionManager.shared.currentPlan
        if plan.isUnlimited { return Int.max }
        return plan.monthlyLimit
    }
    
    var isUnlimited: Bool { SubscriptionManager.shared.currentPlan.isUnlimited }
    var usedCount: Int { currentMonthCount }
    
    var displayRemainingCount: Int {
        if isUnlimited { return Int.max }
        return max(0, monthlyLimit - currentMonthCount)
    }
    
    var canGenerate: Bool { isUnlimited || remainingCount > 0 }
    
    private init() { refreshRemainingCount() }
    
    func refreshForPlanChange() { refreshRemainingCount() }
    
    func recordSuccess() {
        currentMonthCount += 1
        refreshRemainingCount()
        objectWillChange.send()
        print("\u{1F4CA} [UsageLimiter] Usage recorded. Remaining: \(remainingCount)")
    }
    
    func checkRemainingCount() -> Int {
        refreshRemainingCount()
        return remainingCount
    }
    
    func isLimitReached() -> Bool {
        if isUnlimited { return false }
        refreshRemainingCount()
        return remainingCount <= 0
    }
    
    func getNextResetDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) else {
            return now
        }
        return firstDay
    }
    
    func daysUntilReset() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: getNextResetDate())
        return components.day ?? 0
    }
    
    private var currentMonthCount: Int {
        get { UserDefaults.standard.integer(forKey: keyPrefix + currentMonthKey) }
        set { UserDefaults.standard.set(newValue, forKey: keyPrefix + currentMonthKey) }
    }
    
    private var currentMonthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
    
    private func refreshRemainingCount() {
        if isUnlimited { remainingCount = Int.max; return }
        remainingCount = max(0, monthlyLimit - currentMonthCount)
    }
}
