import SwiftUI
import UIKit

/// Haptic Feedback Manager
/// 重要なアクションに対して触覚フィードバックを提供
struct HapticFeedback {
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
    
    /// 選択フィードバック（タブ切り替え、ピッカー選択）
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// MARK: - Button Modifiers with Haptic & Micro-interactions

/// インタラクティブなボタンスタイル（スケール＋Haptic）
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
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    triggerHaptic()
                }
            }
    }
    
    private func triggerHaptic() {
        switch hapticStyle {
        case .light: HapticFeedback.light()
        case .medium: HapticFeedback.medium()
        case .heavy: HapticFeedback.heavy()
        case .selection: HapticFeedback.selection()
        }
    }
}

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

// MARK: - View Extensions

extension View {
    /// インタラクティブボタンスタイルを適用
    func interactiveButton(
        haptic: InteractiveButtonStyle.HapticType = .light,
        scale: CGFloat = 0.95
    ) -> some View {
        buttonStyle(InteractiveButtonStyle(hapticStyle: haptic, scaleEffect: scale))
    }
    
    /// ホバー時のグロー効果を追加
    func hoverGlow(color: Color = Theme.forestGreen) -> some View {
        modifier(HoverGlowModifier(glowColor: color))
    }
    
    /// カードタップアニメーションを追加
    func cardTapAnimation() -> some View {
        modifier(CardTapModifier())
    }
}
