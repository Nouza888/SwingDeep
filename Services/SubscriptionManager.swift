import Foundation
import SwiftUI
import Combine

// MARK: - サブスクリプションプラン

/// アプリのサブスクリプションプラン定義
///
/// ## プラン一覧
/// - Free: 無料プラン（週10回制限）
/// - Standard: スタンダードプラン（月50回制限）
/// - Premium: プレミアムプラン（無制限）
enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case free = "Free"
    case standard = "Standard"
    case premium = "Premium"

    // MARK: - Identifiable

    var id: String { rawValue }

    // MARK: - Display Properties

    /// 表示名
    var name: String {
        switch self {
        case .free: return "Free"
        case .standard: return "Standard (Light)"
        case .premium: return "Premium (Pro)"
        }
    }

    /// SF Symbolsアイコン名
    var icon: String {
        switch self {
        case .free: return "egg.fill"
        case .standard: return "medal.fill"
        case .premium: return "crown.fill"
        }
    }

    /// テーマカラー
    var color: Color {
        switch self {
        case .free: return .gray
        case .standard: return .blue
        case .premium: return .yellow
        }
    }

    // MARK: - Feature Access

    /// トレンドグラフ閲覧権限
    var canViewTrendGraph: Bool {
        self == .premium
    }

    /// 全診断項目閲覧権限
    var canViewAllDiagnosisItems: Bool {
        self != .free
    }

    /// 動画比較機能使用権限
    var canCompareVideo: Bool {
        self == .premium
    }

    /// 月あたりの最大解析回数
    var monthlyLimit: Int {
        switch self {
        case .free: return 15       // 月15回
        case .standard: return 40   // 月40回
        case .premium: return Int.max  // 無制限
        }
    }

    /// 無制限かどうか
    var isUnlimited: Bool {
        self == .premium
    }
}

// MARK: - サブスクリプション管理

/// サブスクリプション状態を管理するシングルトン
///
/// ## 機能
/// - 現在のプラン状態を保持
/// - プランアップグレード処理（現在はMVP用のモック実装）
///
/// ## TODO: 本番実装
/// - RevenueCat/StoreKit連携
/// - 購入履歴の永続化
/// - レシート検証
class SubscriptionManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SubscriptionManager()

    // MARK: - Published Properties

    /// 現在のサブスクリプションプラン
    @Published var currentPlan: SubscriptionPlan = .free

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// プランを変更する
    ///
    /// - Parameter plan: 変更先のプラン
    ///
    /// - Note: 現在はMVP用のモック実装です。
    ///         本番では課金処理とレシート検証を行います。
    func upgrade(to plan: SubscriptionPlan) {
        self.currentPlan = plan
    }

    /// 無料プランにダウングレードする
    func downgradeToFree() {
        self.currentPlan = .free
    }

    /// 現在のプランの機能制限情報を取得
    /// - Returns: 機能制限の説明文
    func currentPlanDescription() -> String {
        switch currentPlan {
        case .free:
            return "月\(currentPlan.monthlyLimit)回まで解析可能"
        case .standard:
            return "月\(currentPlan.monthlyLimit)回まで解析可能"
        case .premium:
            return "無制限に解析可能"
        }
    }
}
