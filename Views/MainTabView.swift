import SwiftUI

// MARK: - メインタブ画面

/// アプリのメイン画面（タブナビゲーション）
///
/// ## 機能
/// - 分析タブ（ContentView）
/// - 履歴タブ（HistoryView）
/// - 設定タブ（SettingsView）
///
/// ## 設計
/// - カスタムタブバーを使用（SwiftUI標準のTabViewではなく）
/// - ガラスモーフィズムデザイン
/// - 言語変更時に自動で画面を再構築
struct MainTabView: View {
    
    // MARK: - Properties
    
    /// 選択中のタブインデックス
    @State private var selectedTab = 0
    
    /// 言語管理（言語変更時に画面再構築のため監視）
    @ObservedObject var languageManager = LanguageManager.shared
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // タブコンテンツ
            tabContent
            
            // カスタムタブバー
            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, Theme.Spacing.base.rawValue)
                .padding(.bottom, Theme.Spacing.sm.rawValue)
        }
        .edgesIgnoringSafeArea(.bottom)
        .id(languageManager.currentLanguage) // 言語変更時に画面を再構築
    }
    
    // MARK: - Components
    
    /// タブコンテンツ
    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tag(0)
            
            HistoryView()
                .tag(1)
            
            SettingsView()
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

// MARK: - カスタムタブバー

/// カスタムタブバーコンポーネント
///
/// ## デザイン
/// - ガラスモーフィズム背景
/// - グラデーション枠線
/// - シャドウ効果
struct CustomTabBar: View {
    
    // MARK: - Properties
    
    /// 選択中のタブ（親ビューからバインディング）
    @Binding var selectedTab: Int
    
    /// タブ定義（アイコン、ラベル）
    private var tabs: [(icon: String, label: String)] {
        [
            ("figure.golf", "tab_diagnose".localized),
            ("chart.line.uptrend.xyaxis", "tab_history".localized),
            ("gearshape.fill", "tab_settings".localized)
        ]
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                TabBarItem(
                    icon: tabs[index].icon,
                    label: tabs[index].label,
                    isSelected: selectedTab == index
                )
                .onTapGesture {
                    handleTabTap(index: index)
                }
                
                // タブ間のスペーサー
                if index < tabs.count - 1 {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg.rawValue)
        .padding(.vertical, Theme.Spacing.md.rawValue)
        .background(tabBarBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLg))
        .shadow(color: Theme.primary.opacity(0.1), radius: 20, x: 0, y: 10)
        .shadow(color: Theme.forestGreen.opacity(0.05), radius: 12, x: 0, y: 6)
    }
    
    // MARK: - Components
    
    /// タブバー背景
    private var tabBarBackground: some View {
        ZStack {
            // ガラスモーフィズム背景
            RoundedRectangle(cornerRadius: Theme.cornerRadiusLg)
                .fill(Theme.glassGradient)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusLg)
                        .fill(.ultraThinMaterial)
                )
            
            // グラデーション枠線
            RoundedRectangle(cornerRadius: Theme.cornerRadiusLg)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Theme.accent.opacity(0.5),
                            Color.white.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
    }
    
    // MARK: - Actions
    
    /// タブタップ時の処理
    private func handleTabTap(index: Int) {
        HapticFeedback.selection()
        withAnimation(Theme.springAnimation) {
            selectedTab = index
        }
    }
}

// MARK: - タブバーアイテム

/// 個々のタブアイテム
struct TabBarItem: View {
    
    // MARK: - Properties
    
    /// SF Symbolsアイコン名
    let icon: String
    
    /// 表示ラベル
    let label: String
    
    /// 選択状態
    let isSelected: Bool
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xs.rawValue) {
            // アイコン
            Image(systemName: icon)
                .font(.system(size: 24, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? Theme.forestGreen : Theme.textSecondary)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(Theme.springAnimation, value: isSelected)
            
            // ラベル
            Text(label)
                .typography(.caption)
                .foregroundColor(isSelected ? Theme.forestGreen : Theme.textSecondary)
                .fontWeight(isSelected ? .semibold : .medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xs.rawValue)
        .background(selectionBackground)
    }
    
    // MARK: - Components
    
    /// 選択時の背景
    private var selectionBackground: some View {
        RoundedRectangle(cornerRadius: Theme.cornerRadius)
            .fill(isSelected ? Theme.forestGreen.opacity(0.1) : Color.clear)
            .animation(Theme.smoothAnimation, value: isSelected)
    }
}
