import SwiftUI

// =============================================================================
// MARK: - SwingDeep デザインシステム
// =============================================================================
// アプリ全体で使用される色、タイポグラフィ、スペーシング、アニメーションの定義
// Note: このファイルはデータ定義のみを含み、View拡張は HapticFeedback.swift に配置

struct Theme {
    
    // MARK: - カラーパレット
    
    // プライマリカラー（モノクローム）
    static let primary = Color(hex: "000000")      // 黒
    static let secondary = Color(hex: "8E8E93")    // システムグレー
    static let tertiary = Color(hex: "C7C7CC")     // ライトグレー
    
    // 背景色
    static let background = Color(hex: "F2F2F7")   // システムグループ背景
    static let surface = Color(hex: "FFFFFF")      // 純白
    
    // アクセントカラー
    static let accent = Color(hex: "007AFF")       // システムブルー
    static let forestGreen = Color(hex: "34C759")  // システムグリーン（成功/ゴルフ）
    static let championshipGold = Color(hex: "FFCC00") // システムイエロー（ハイライト）
    static let error = Color(hex: "FF3B30")        // システムレッド
    
    // ドメイン固有カラー
    static let address = Color(hex: "FF3B30")      // アドレス（構え）用の赤
    static let impact = Color(hex: "007AFF")       // インパクト用の青
    
    // テキストカラー
    static let textPrimary = Color(hex: "000000")
    static let textSecondary = Color(hex: "6C6C70")
    static let textTertiary = Color(hex: "AEAEB2")
    
    // UI要素
    static let separator = Color(hex: "C6C6C8")
    static let glassMaterial = Material.regular
    
    // MARK: - グラデーション
    
    /// ガラス風グラデーション
    static let glassGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.9),
            Color.white.opacity(0.6)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// プライマリグラデーション（ダークグレー）
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "1C1C1E"), Color(hex: "3A3A3C")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// ヒーローボタン用グラデーション
    static let heroGradient = primaryGradient
    
    /// シマーエフェクト用グラデーション
    static let shimmerGradient = LinearGradient(
        colors: [
            forestGreen.opacity(0.3),
            championshipGold.opacity(0.5),
            forestGreen.opacity(0.3)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - タイポグラフィ
    
    enum Typography {
        case displayLarge   // 72pt - メインタイトル
        case displayMedium  // 48pt - サブタイトル
        case headlineLarge  // 28pt - セクションヘッダー
        case headlineMedium // 20pt - カードタイトル
        case bodyLarge      // 17pt - 本文（強調）
        case bodyMedium     // 15pt - 本文（通常）
        case caption        // 13pt - キャプション
        case dataLarge      // 64pt - 大きな数値表示
        case dataMedium     // 20pt - 中程度の数値表示
        
        var font: Font {
            switch self {
            case .displayLarge:  return .system(size: 72, weight: .heavy, design: .rounded)
            case .displayMedium: return .system(size: 48, weight: .heavy, design: .rounded)
            case .headlineLarge: return .system(size: 28, weight: .bold, design: .default)
            case .headlineMedium: return .system(size: 20, weight: .semibold, design: .default)
            case .bodyLarge:     return .system(size: 17, weight: .medium, design: .default)
            case .bodyMedium:    return .system(size: 15, weight: .regular, design: .default)
            case .caption:       return .system(size: 13, weight: .medium, design: .default)
            case .dataLarge:     return .system(size: 64, weight: .semibold, design: .monospaced)
            case .dataMedium:    return .system(size: 20, weight: .semibold, design: .monospaced)
            }
        }
    }
    
    // MARK: - スペーシング
    
    enum Spacing: CGFloat {
        case xs = 4
        case sm = 8
        case md = 12
        case base = 16
        case lg = 24
        case xl = 32
        case xxl = 48
        case xxxl = 64
    }
    
    // MARK: - レイアウト定数
    
    static let cornerRadiusSm: CGFloat = 12
    static let cornerRadius: CGFloat = 20
    static let cornerRadiusLg: CGFloat = 28
    
    static let borderWidth: CGFloat = 1.5
    static let shadowRadius: CGFloat = 20
    static let glassBlurRadius: CGFloat = 20
    
    // MARK: - アニメーション
    
    /// スプリングアニメーション（バウンス効果）
    static let springAnimation = Animation.spring(response: 0.5, dampingFraction: 0.7)
    
    /// スムーズアニメーション（標準的なイージング）
    static let smoothAnimation = Animation.easeInOut(duration: 0.3)
    
    /// クイックアニメーション（高速レスポンス）
    static let quickAnimation = Animation.easeOut(duration: 0.2)
}

// =============================================================================
// MARK: - Color 拡張（16進数カラーコード対応）
// =============================================================================

extension Color {
    /// 16進数カラーコードからColorを初期化
    /// - Parameter hex: 16進数カラーコード（3桁、6桁、8桁対応）
    /// - Note: 例: "FF0000"（赤）、"007AFF"（システムブルー）
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0) // デフォルト: 黒
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// =============================================================================
// MARK: - View拡張（タイポグラフィ、アニメーション）
// =============================================================================

extension View {
    /// タイポグラフィスタイルを適用
    /// - Parameter style: 適用するタイポグラフィスタイル
    func typography(_ style: Theme.Typography) -> some View {
        self.font(style.font)
    }
    
    /// リストアイテムの段階的フェードインアニメーション
    /// - Parameters:
    ///   - index: アイテムのインデックス（遅延計算用）
    ///   - total: 全アイテム数（現在未使用だが将来の拡張用）
    func staggeredAppearance(index: Int, total: Int) -> some View {
        self
            .opacity(1)
            .offset(y: 0)
            .animation(
                Theme.smoothAnimation.delay(Double(index) * 0.1),
                value: index
            )
    }
}
