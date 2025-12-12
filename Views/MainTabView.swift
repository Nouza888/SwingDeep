import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab Content
            TabView(selection: $selectedTab) {
                ContentView()
                    .tag(0)
                
                HistoryView()
                    .tag(1)
                
                SettingsView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, Theme.Spacing.base.rawValue)
                .padding(.bottom, Theme.Spacing.sm.rawValue)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    let tabs: [(icon: String, label: String)] = [
        ("figure.golf", "tab_diagnose".localized),
        ("chart.line.uptrend.xyaxis", "tab_history".localized),
        ("gearshape.fill", "tab_settings".localized)
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                TabBarItem(
                    icon: tabs[index].icon,
                    label: tabs[index].label,
                    isSelected: selectedTab == index
                )
                .onTapGesture {
                    HapticFeedback.selection()
                    withAnimation(Theme.springAnimation) {
                        selectedTab = index
                    }
                }
                
                if index < tabs.count - 1 {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg.rawValue)
        .padding(.vertical, Theme.Spacing.md.rawValue)
        .background(
            ZStack {
                // Glassmorphic background
                RoundedRectangle(cornerRadius: Theme.cornerRadiusLg)
                    .fill(Theme.glassGradient)
                    .background(.ultraThinMaterial)
                
                // Border gradient
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
        )
        .shadow(
            color: Theme.primary.opacity(0.1),
            radius: 20,
            x: 0,
            y: 10
        )
        .shadow(
            color: Theme.forestGreen.opacity(0.05),
            radius: 12,
            x: 0,
            y: 6
        )
    }
}

struct TabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xs.rawValue) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? Theme.forestGreen : Theme.textSecondary)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(Theme.springAnimation, value: isSelected)
            
            Text(label)
                .typography(.caption)
                .foregroundColor(isSelected ? Theme.forestGreen : Theme.textSecondary)
                .fontWeight(isSelected ? .semibold : .medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xs.rawValue)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(isSelected ? Theme.forestGreen.opacity(0.1) : Color.clear)
                .animation(Theme.smoothAnimation, value: isSelected)
        )
    }
}
