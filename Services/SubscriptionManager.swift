import Foundation
import SwiftUI
import Combine
enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case free = "Free"
    case standard = "Standard"
    case premium = "Premium"
    
    var id: String { rawValue }
    
    var name: String {
        switch self {
        case .free: return "Free"
        case .standard: return "Standard (Light)"
        case .premium: return "Premium (Pro)"
        }
    }
    
    var icon: String {
        switch self {
        case .free: return "egg.fill"
        case .standard: return "medal.fill"
        case .premium: return "crown.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .free: return .gray
        case .standard: return .blue
        case .premium: return .yellow
        }
    }
    
    // 機能制限の定義
    var canViewTrendGraph: Bool { self == .premium }
    var canViewAllDiagnosisItems: Bool { self != .free }
    var canCompareVideo: Bool { self == .premium }
    var maxAnalysisCount: Int {
        switch self {
        case .free: return 10 // 週10回
        case .standard: return 50 // 月50回
        case .premium: return Int.max
        }
    }
}
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var currentPlan: SubscriptionPlan = .free
    
    private init() {}
    
    /// プランを変更する（デバッグ用・MVP用）
    func upgrade(to plan: SubscriptionPlan) {
        self.currentPlan = plan
    }
}
