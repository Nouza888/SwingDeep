import SwiftUI

/// SwingDeep Design System: "Precision Meets Performance"
/// Golf Clubhouse Luxe × Modern Sports Tech
struct Theme {
    // MARK: - Color Palette (Modern Gray / Apple-like)
    
    // Primary Colors (Monochrome)
    static let primary = Color(hex: "000000")      // Black
    static let secondary = Color(hex: "8E8E93")    // System Gray
    static let tertiary = Color(hex: "C7C7CC")     // Light Gray
    
    // Backgrounds
    static let background = Color(hex: "F2F2F7")   // System Grouped Background (Light Gray)
    static let surface = Color(hex: "FFFFFF")      // Pure White
    
    // Accents (Minimalist)
    static let accent = Color(hex: "007AFF")       // System Blue (Standard iOS Action Color)
    static let forestGreen = Color(hex: "34C759")  // System Green (Success/Golf)
    static let championshipGold = Color(hex: "FFCC00") // System Yellow (Highlight)
    static let error = Color(hex: "FF3B30")        // System Red
    static let accentOrange = Color(hex: "FF9500") // System Orange (Warning)
    
    // Domain Specific Colors
    static let address = Color(hex: "FF3B30")      // Red for Address (Start)
    static let impact = Color(hex: "007AFF")       // Blue for Impact (Hit)
    
    // Text Colors
    static let textPrimary = Color(hex: "000000")
    static let textSecondary = Color(hex: "6C6C70") // Secondary Label Color
    static let textTertiary = Color(hex: "AEAEB2")
    
    // UI Elements
    static let separator = Color(hex: "C6C6C8")
    static let glassMaterial = Material.regular
    
    // Gradients (Subtle)
    static let glassGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.9),
            Color.white.opacity(0.6)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "1C1C1E"), Color(hex: "3A3A3C")], // Dark Gray Gradient
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Alias for primary gradient used in buttons
    static let heroGradient = primaryGradient
    
    static let shimmerGradient = LinearGradient(
        colors: [
            forestGreen.opacity(0.3),
            championshipGold.opacity(0.5),
            forestGreen.opacity(0.3)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Typography
    
    enum Typography {
        case displayLarge
        case displayMedium
        case headlineLarge
        case headlineMedium
        case bodyLarge
        case bodyMedium
        case caption
        case dataLarge
        case dataMedium
        
        var font: Font {
            switch self {
            case .displayLarge: return .system(size: 72, weight: .heavy, design: .rounded)
            case .displayMedium: return .system(size: 48, weight: .heavy, design: .rounded)
            case .headlineLarge: return .system(size: 28, weight: .bold, design: .default)
            case .headlineMedium: return .system(size: 20, weight: .semibold, design: .default)
            case .bodyLarge: return .system(size: 17, weight: .medium, design: .default)
            case .bodyMedium: return .system(size: 15, weight: .regular, design: .default)
            case .caption: return .system(size: 13, weight: .medium, design: .default)
            case .dataLarge: return .system(size: 64, weight: .semibold, design: .monospaced)
            case .dataMedium: return .system(size: 20, weight: .semibold, design: .monospaced)
            }
        }
    }
    
    // MARK: - Spacing
    
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
    
    // MARK: - Layout
    
    static let cornerRadiusSm: CGFloat = 12
    static let cornerRadius: CGFloat = 20
    static let cornerRadiusLg: CGFloat = 28
    
    static let borderWidth: CGFloat = 1.5
    static let shadowRadius: CGFloat = 20
    static let glassBlurRadius: CGFloat = 20
    
    // MARK: - Animation
    
    static let springAnimation = Animation.spring(response: 0.5, dampingFraction: 0.7)
    static let smoothAnimation = Animation.easeInOut(duration: 0.3)
    static let quickAnimation = Animation.easeOut(duration: 0.2)
    
    /// Glass Material Effect
    // static var glassMaterial: Material { return .ultraThinMaterial } // Removed duplicate
}

// MARK: - Color Extension for Hex

extension Color {
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
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

struct ThemeGlassCardModifier: ViewModifier {
    var elevation: Elevation = .medium
    
    enum Elevation {
        case subtle, medium, prominent
        
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
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .fill(Theme.glassGradient)
                        .background(.ultraThinMaterial)
                    
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

struct PrimaryButtonModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .font(Theme.Typography.headlineMedium.font)
            .foregroundColor(.white)
            .padding(.vertical, Theme.Spacing.base.rawValue)
            .padding(.horizontal, Theme.Spacing.xl.rawValue)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    Theme.heroGradient
                    
                    // Shimmer overlay
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
            )
            .cornerRadius(Theme.cornerRadius)
            .shadow(
                color: Theme.championshipGold.opacity(0.4),
                radius: isPressed ? 8 : 12,
                x: 0,
                y: isPressed ? 3 : 6
            )
            .shadow(
                color: Theme.forestGreen.opacity(0.3),
                radius: isPressed ? 4 : 8,
                x: 0,
                y: isPressed ? 2 : 3
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(Theme.quickAnimation, value: isPressed)
            .hoverGlow(color: Theme.championshipGold)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticFeedback.medium()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

struct SecondaryButtonModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
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
                color: Color.black.opacity(isPressed ? 0.02 : 0.05),
                radius: isPressed ? 4 : 8,
                x: 0,
                y: isPressed ? 2 : 4
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(Theme.quickAnimation, value: isPressed)
            .hoverGlow(color: Theme.forestGreen)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticFeedback.light()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

// MARK: - View Extensions

extension View {
    func glassCard(elevation: ThemeGlassCardModifier.Elevation = .medium) -> some View {
        modifier(ThemeGlassCardModifier(elevation: elevation))
    }
    
    func primaryButtonStyle() -> some View {
        modifier(PrimaryButtonModifier())
    }
    
    func secondaryButtonStyle() -> some View {
        modifier(SecondaryButtonModifier())
    }
    
    func typography(_ style: Theme.Typography) -> some View {
        self.font(style.font)
    }
    
    /// Staggered fade-in animation for lists
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
