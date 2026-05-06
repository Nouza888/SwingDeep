import Foundation
import SwiftUI
import Combine

// MARK: - \u30B5\u30D6\u30B9\u30AF\u30EA\u30D7\u30B7\u30E7\u30F3\u30D7\u30E9\u30F3

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
    
    var canViewTrendGraph: Bool { self == .premium }
    var canViewAllDiagnosisItems: Bool { self != .free }
    var canCompareVideo: Bool { self == .premium }
    
    var monthlyLimit: Int {
        switch self {
        case .free: return 15
        case .standard: return 40
        case .premium: return Int.max
        }
    }
    
    var isUnlimited: Bool { self == .premium }
}

// MARK: - \u30B5\u30D6\u30B9\u30AF\u30EA\u30D7\u30B7\u30E7\u30F3\u7BA1\u7406

class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    @Published var currentPlan: SubscriptionPlan = .free
    private init() {}
    
    func upgrade(to plan: SubscriptionPlan) {
        self.currentPlan = plan
    }
    
    func downgradeToFree() {
        self.currentPlan = .free
    }
    
    func currentPlanDescription() -> String {
        switch currentPlan {
        case .free:
            return "\u6708\(currentPlan.monthlyLimit)\u56DE\u307E\u3067\u89E3\u6790\u53EF\u80FD"
        case .standard:
            return "\u6708\(currentPlan.monthlyLimit)\u56DE\u307E\u3067\u89E3\u6790\u53EF\u80FD"
        case .premium:
            return "\u7121\u5236\u9650\u306B\u89E3\u6790\u53EF\u80FD"
        }
    }
}
