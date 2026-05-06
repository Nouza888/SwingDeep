import Foundation

enum ReportContext: String, Codable {
    case firstTime = "FIRST_TIME"
    case gettingUsed = "GETTING_USED"
    case regular = "REGULAR"
    case comeback = "COMEBACK"
    
    var displayNameJa: String {
        switch self {
        case .firstTime: return "\u521D\u56DE"
        case .gettingUsed: return "\u6163\u308C\u59CB\u3081"
        case .regular: return "\u5E38\u9023"
        case .comeback: return "\u5FA9\u5E30"
        }
    }
}

class ReportContextManager {
    static let shared = ReportContextManager()
    private let reportCountKey = "report_count"
    private let lastReportDateKey = "last_report_date"
    private let comebackThresholdDays = 30
    private init() {}
    
    var reportCount: Int { UserDefaults.standard.integer(forKey: reportCountKey) }
    var lastReportDate: Date? { UserDefaults.standard.object(forKey: lastReportDateKey) as? Date }
    
    func determineContext() -> ReportContext {
        let count = reportCount
        if count == 0 { return .firstTime }
        if isDueForComeback() { return .comeback }
        if count <= 2 { return .gettingUsed }
        return .regular
    }
    
    func recordReportGenerated() {
        let newCount = reportCount + 1
        UserDefaults.standard.set(newCount, forKey: reportCountKey)
        UserDefaults.standard.set(Date(), forKey: lastReportDateKey)
        print("\u{1F4CA} [ReportContextManager] Report recorded. Count: \(newCount), Context: \(determineContext().rawValue)")
    }
    
    func daysSinceLastReport() -> Int {
        guard let lastDate = lastReportDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
    }
    
    private func isDueForComeback() -> Bool { daysSinceLastReport() >= comebackThresholdDays }
    
    #if DEBUG
    func resetForDebug() {
        UserDefaults.standard.removeObject(forKey: reportCountKey)
        UserDefaults.standard.removeObject(forKey: lastReportDateKey)
    }
    func setReportCountForDebug(_ count: Int) {
        UserDefaults.standard.set(count, forKey: reportCountKey)
    }
    func setLastReportDateForDebug(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastReportDateKey)
    }
    #endif
}
