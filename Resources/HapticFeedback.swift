import SwiftUI
import UIKit

// =============================================================================
// MARK: - 触覚フィードバック管理
// =============================================================================
// 重要なアクションに対して触覚フィードバックを提供するユーティリティ

struct HapticFeedback {
    
    // MARK: - インパクトフィードバック
    
    /// 軽いタップフィードバック（一般的なボタンタップ）
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// 中程度のタップフィードバック（重要なアクション）
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// 強いタップフィードバック（非常に重要なアクション）
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    // MARK: - 通知フィードバック
    
    /// 成功フィードバック（診断完了、設定保存など）
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// 警告フィードバック（確認が必要なアクション）
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    /// エラーフィードバック（失敗、エラー発生）
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    // MARK: - 選択フィードバック
    
    /// 選択フィードバック（タブ切り替え、ピッカー選択）
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// =============================================================================
// MARK: - View Modifiers
// =============================================================================

// MARK: - ガラスカードモディファイア

/// ガラスモーフィズム効果を持つカードスタイル
struct GlassCardModifier: ViewModifier {
    var elevation: Elevation = .medium
    
    /// カードの浮き上がり具合を定義
    enum Elevation {
        case subtle     // 控えめ
        case medium     // 標準
        case prominent  // 強調
        
        var shadowRadius: CGFloat {
            switch self {
            case .subtle: return 8
            case .medium: return 16
            case .prominent: return 24
            }
        }
        
        var shadowOpacity: Double {
            switch self {
            case .subtle: return 0.05
            case .medium: return 0.1
            case .prominent: return 0.15
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // ガラス風グラデーション背景
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .fill(Theme.glassGradient)
                        .background(.ultraThinMaterial)
                    
                    // エッジハイライト
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: Theme.borderWidth
                        )
                }
            )
            .shadow(
                color: Theme.forestGreen.opacity(elevation.shadowOpacity),
                radius: elevation.shadowRadius,
                x: 0,
                y: elevation.shadowRadius / 2
            )
            .shadow(
                color: Color.black.opacity(elevation.shadowOpacity / 2),
                radius: elevation.shadowRadius / 2,
                x: 0,
                y: 2
            )
    }
}

// MARK: - チャットバブルモディファイア

/// チャット風の吹き出しスタイル
struct ChatBubbleModifier: ViewModifier {
    var isMyMessage: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isMyMessage ? Theme.accent.opacity(0.15) : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.separator.opacity(0.5), lineWidth: isMyMessage ? 0 : 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - ホバーグローモディファイア

/// ホバー時のグロー効果（iPad/Mac対応）
struct HoverGlowModifier: ViewModifier {
    @State private var isHovered = false
    let glowColor: Color
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: isHovered ? glowColor.opacity(0.5) : Color.clear,
                radius: isHovered ? 20 : 0
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(Theme.smoothAnimation, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - カードタップモディファイア

/// カードのマイクロインタラクション（タップ時の反応）
struct CardTapModifier: ViewModifier {
    @State private var isTapped = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isTapped ? 0.98 : 1.0)
            .animation(Theme.quickAnimation, value: isTapped)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isTapped {
                            isTapped = true
                            HapticFeedback.light()
                        }
                    }
                    .onEnded { _ in
                        isTapped = false
                    }
            )
    }
}

// =============================================================================
// MARK: - Button Styles
// =============================================================================

// MARK: - プライマリボタンスタイル

/// メインアクション用のボタンスタイル
/// - 暗いグラデーション背景
/// - ゴールドとグリーンのシャドウ
/// - タップ時のスケールエフェクトとホバーグロー
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonContent(configuration: configuration)
    }
}

/// プライマリボタンの内部ビュー（onChange対応のため分離）
private struct PrimaryButtonContent: View {
    let configuration: ButtonStyleConfiguration
    
    var body: some View {
        configuration.label
            .font(Theme.Typography.headlineMedium.font)
            .foregroundColor(.white)
            .padding(.vertical, Theme.Spacing.base.rawValue)
            .padding(.horizontal, Theme.Spacing.xl.rawValue)
            .frame(maxWidth: .infinity)
            .background(backgroundView)
            .cornerRadius(Theme.cornerRadius)
            .shadow(
                color: Theme.championshipGold.opacity(0.4),
                radius: configuration.isPressed ? 8 : 12,
                x: 0,
                y: configuration.isPressed ? 3 : 6
            )
            .shadow(
                color: Theme.forestGreen.opacity(0.3),
                radius: configuration.isPressed ? 4 : 8,
                x: 0,
                y: configuration.isPressed ? 2 : 3
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(Theme.quickAnimation, value: configuration.isPressed)
            .modifier(HoverGlowModifier(glowColor: Theme.championshipGold))
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedback.medium()
                }
            }
    }
    
    /// ボタン背景（グラデーション + シマー）
    private var backgroundView: some View {
        ZStack {
            Theme.heroGradient
            
            // シマーオーバーレイ
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.2),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(0.5)
        }
    }
}

// MARK: - セカンダリボタンスタイル

/// サブアクション用のボタンスタイル
/// - 白背景 + グリーンボーダー
/// - タップ時のスケールエフェクト
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SecondaryButtonContent(configuration: configuration)
    }
}

/// セカンダリボタンの内部ビュー
private struct SecondaryButtonContent: View {
    let configuration: ButtonStyleConfiguration
    
    var body: some View {
        configuration.label
            .font(Theme.Typography.headlineMedium.font)
            .foregroundColor(Theme.forestGreen)
            .padding(.vertical, Theme.Spacing.base.rawValue)
            .padding(.horizontal, Theme.Spacing.xl.rawValue)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .stroke(Theme.forestGreen, lineWidth: 2)
                    )
            )
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.02 : 0.05),
                radius: configuration.isPressed ? 4 : 8,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(Theme.quickAnimation, value: configuration.isPressed)
            .modifier(HoverGlowModifier(glowColor: Theme.forestGreen))
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedback.light()
                }
            }
    }
}

// MARK: - インタラクティブボタンスタイル

/// スケール＋Hapticフィードバック付きボタンスタイル
struct InteractiveButtonStyle: ButtonStyle {
    var hapticStyle: HapticType = .light
    var scaleEffect: CGFloat = 0.95
    
    enum HapticType {
        case light, medium, heavy, selection
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleEffect : 1.0)
            .animation(Theme.quickAnimation, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    triggerHaptic()
                }
            }
    }
    
    /// 設定されたスタイルに応じたHapticを発火
    private func triggerHaptic() {
        switch hapticStyle {
        case .light: HapticFeedback.light()
        case .medium: HapticFeedback.medium()
        case .heavy: HapticFeedback.heavy()
        case .selection: HapticFeedback.selection()
        }
    }
}

// =============================================================================
// MARK: - View Extensions
// =============================================================================

extension View {
    
    // MARK: - カード・バブル系
    
    /// ガラスカードスタイルを適用
    /// - Parameter elevation: カードの浮き上がり具合
    func glassCard(elevation: GlassCardModifier.Elevation = .medium) -> some View {
        modifier(GlassCardModifier(elevation: elevation))
    }
    
    /// チャットバブルスタイルを適用
    /// - Parameter isMyMessage: 自分のメッセージかどうか（背景色が変わる）
    func chatBubble(isMyMessage: Bool = false) -> some View {
        modifier(ChatBubbleModifier(isMyMessage: isMyMessage))
    }
    
    // MARK: - エフェクト系
    
    /// ホバー時のグロー効果を追加（iPad/Mac対応）
    /// - Parameter color: グローの色
    func hoverGlow(color: Color = Theme.forestGreen) -> some View {
        modifier(HoverGlowModifier(glowColor: color))
    }
    
    /// カードタップアニメーションを追加
    func cardTapAnimation() -> some View {
        modifier(CardTapModifier())
    }
    
    // MARK: - ボタンスタイル
    
    /// インタラクティブボタンスタイルを適用
    /// - Parameters:
    ///   - haptic: 触覚フィードバックの強さ
    ///   - scale: タップ時のスケール倍率
    func interactiveButton(
        haptic: InteractiveButtonStyle.HapticType = .light,
        scale: CGFloat = 0.95
    ) -> some View {
        buttonStyle(InteractiveButtonStyle(hapticStyle: haptic, scaleEffect: scale))
    }
}

// MARK: - ButtonStyle 静的拡張

extension ButtonStyle where Self == PrimaryButtonStyle {
    /// プライマリボタンスタイルへのショートカット
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    /// セカンダリボタンスタイルへのショートカット
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
