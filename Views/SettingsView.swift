import SwiftUI

// MARK: - 設定画面

/// アプリ設定画面
///
/// ## 機能
/// - プラン設定（Free/Premium）
/// - 言語設定（日本語/英語）
/// - AIコーチ選択
/// - アプリ情報表示
struct SettingsView: View {
    
    // MARK: - Properties
    
    /// サブスクリプション管理
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    
    /// 利用回数管理
    @ObservedObject var usageLimiter = UsageLimiter.shared
    
    /// 言語管理
    @ObservedObject var languageManager = LanguageManager.shared
    
    /// 選択中のコーチID（UserDefaultsに永続化）
    @AppStorage("coachModeId") private var coachModeId: String = "gentle_sister"
    
    /// 選択中のコーチペルソナ（Binding）
    private var selectedPersona: Binding<CoachPersona> {
        Binding(
            get: {
                let personas = CoachPersona.availablePersonas(for: languageManager.currentLanguage)
                return personas.first(where: { $0.id == coachModeId }) ?? CoachPersona.standard
            },
            set: { newValue in
                coachModeId = newValue.id
            }
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                usageStatusSection      // 利用状況（新規追加）
                planSettingsSection
                languageSettingsSection
                coachSettingsSection
                appInfoSection
                bottomSpacerSection
            }
            .navigationTitle("settings_title".localized)
        }
    }
    
    // MARK: - Sections
    
    /// 利用状況セクション
    private var usageStatusSection: some View {
        Section(header: Text("usage_status".localized)) {
            // 今月の利用回数
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("monthly_usage".localized)
                        .font(.subheadline)
                    Text(String(format: "reports_used".localized, usageLimiter.usedCount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if usageLimiter.isUnlimited {
                    Text("unlimited".localized)
                        .font(.headline)
                        .foregroundColor(Theme.forestGreen)
                } else {
                    Text("\(usageLimiter.displayRemainingCount)/\(usageLimiter.monthlyLimit)")
                        .font(.headline)
                        .foregroundColor(usageLimiter.displayRemainingCount > 5 ? Theme.forestGreen : Theme.accentOrange)
                }
            }
            
            // 次回リセット日（Premiumは非表示）
            if !usageLimiter.isUnlimited {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(Theme.accent)
                    Text("next_reset".localized)
                    Spacer()
                    Text(usageLimiter.getNextResetDate(), style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // レポート回数（ReportContextManager）
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(Theme.accent)
                Text("total_reports".localized)
                Spacer()
                Text(String(format: "reports_count".localized, ReportContextManager.shared.reportCount))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        // プラン変更時にUsageLimiterを更新
        .onChange(of: subscriptionManager.currentPlan) { _ in
            usageLimiter.refreshForPlanChange()
        }
    }
    
    /// プラン設定セクション
    private var planSettingsSection: some View {
        Section(header: Text("plan_settings".localized)) {
            // プラン選択ピッカー
            Picker("current_plan".localized, selection: $subscriptionManager.currentPlan) {
                ForEach(SubscriptionPlan.allCases) { plan in
                    planRowView(for: plan)
                }
            }
            .pickerStyle(.navigationLink)
            
            // 無料プランの場合はアップグレードボタンを表示
            if subscriptionManager.currentPlan == .free {
                upgradeButton
            }
        }
    }
    
    /// 言語設定セクション
    private var languageSettingsSection: some View {
        Section(header: Text("language_settings".localized)) {
            Picker("language_settings".localized, selection: $languageManager.currentLanguage) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .onChange(of: languageManager.currentLanguage) { newValue in
                languageManager.setLanguage(newValue)
            }
        }
    }
    
    /// コーチ設定セクション
    private var coachSettingsSection: some View {
        Section(header: Text("coach_settings".localized)) {
            // コーチ選択ピッカー
            Picker("default_coach".localized, selection: selectedPersona) {
                let personas = CoachPersona.availablePersonas(for: languageManager.currentLanguage)
                ForEach(personas) { persona in
                    Text("\(persona.icon) \(persona.name)").tag(persona)
                }
            }
            
            // 注釈
            Text("coach_note".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    /// アプリ情報セクション
    private var appInfoSection: some View {
        Section(header: Text("app_info".localized)) {
            // バージョン表示
            HStack {
                Text("version".localized)
                Spacer()
                Text(AppConfig.appVersion)
                    .foregroundColor(.secondary)
            }
            
            // 利用規約リンク
            Link("terms".localized, destination: URL(string: "https://nouza888.github.io/golfscan-ai-legal/terms.html")!)
            
            // プライバシーポリシーリンク
            Link("privacy".localized, destination: URL(string: "https://nouza888.github.io/golfscan-ai-legal/")!)
        }
    }
    
    /// タブバーとの重なりを防ぐための余白セクション
    private var bottomSpacerSection: some View {
        Section {
            Color.clear
                .frame(height: 80)
                .listRowBackground(Color.clear)
        }
    }
    
    // MARK: - Component Views
    
    /// プラン行のビュー
    private func planRowView(for plan: SubscriptionPlan) -> some View {
        HStack {
            Image(systemName: plan.icon)
                .foregroundColor(plan.color)
            Text(plan.name)
        }
        .tag(plan)
    }
    
    /// プレミアムアップグレードボタン
    private var upgradeButton: some View {
        Button(action: { subscriptionManager.upgrade(to: .premium) }) {
            HStack {
                Image(systemName: "sparkles")
                Text("upgrade_premium".localized)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.orange, .pink]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(10)
        }
        .listRowInsets(EdgeInsets())
        .padding()
    }
}
