import SwiftUI

// =============================================================================
// MARK: - 設定画面
// =============================================================================
// アプリの各種設定を管理する画面
// - サブスクリプションプラン
// - 言語設定
// - AIコーチ設定
// - アプリ情報

struct SettingsView: View {
    
    // MARK: - プロパティ
    
    /// サブスクリプション管理（シングルトン）
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    
    /// 言語管理（シングルトン）
    @ObservedObject var languageManager = LanguageManager.shared
    
    /// 選択中のコーチモードID（UserDefaultsに永続化）
    @AppStorage("coachModeId") private var coachModeId: String = "normal_jp"
    
    // MARK: - 計算プロパティ
    
    /// 選択中のコーチペルソナへのバインディング
    /// - Note: coachModeIdとCoachPersonaオブジェクト間の変換を行う
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
    
    // MARK: - ビュー本体
    
    var body: some View {
        NavigationView {
            List {
                planSettingsSection
                languageSettingsSection
                coachSettingsSection
                appInfoSection
            }
            .navigationTitle("settings_title".localized)
        }
    }
    
    // MARK: - プライベートビュー
    
    /// プラン設定セクション
    private var planSettingsSection: some View {
        Section(header: Text("plan_settings".localized)) {
            // 現在のプラン選択
            Picker("current_plan".localized, selection: $subscriptionManager.currentPlan) {
                ForEach(SubscriptionPlan.allCases) { plan in
                    planRow(for: plan)
                }
            }
            .pickerStyle(.navigationLink)
            
            // 無料プランの場合はアップグレードボタンを表示
            if subscriptionManager.currentPlan == .free {
                upgradePremiumButton
            }
        }
    }
    
    /// プラン選択行の表示
    private func planRow(for plan: SubscriptionPlan) -> some View {
        HStack {
            Image(systemName: plan.icon)
                .foregroundColor(plan.color)
            Text(plan.name)
        }
        .tag(plan)
    }
    
    /// プレミアムアップグレードボタン
    private var upgradePremiumButton: some View {
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
    
    /// 言語設定セクション
    private var languageSettingsSection: some View {
        Section(header: Text("language_settings".localized)) {
            Picker("language_settings".localized, selection: $languageManager.currentLanguage) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .onChange(of: languageManager.currentLanguage) { _, newValue in
                handleLanguageChange(newValue)
            }
        }
    }
    
    /// 言語変更時の処理
    /// - Parameter newLanguage: 新しく選択された言語
    private func handleLanguageChange(_ newLanguage: AppLanguage) {
        languageManager.setLanguage(newLanguage)
        HapticFeedback.selection()
    }
    
    /// コーチ設定セクション
    private var coachSettingsSection: some View {
        Section(header: Text("coach_settings".localized)) {
            Picker("default_coach".localized, selection: selectedPersona) {
                let personas = CoachPersona.availablePersonas(for: languageManager.currentLanguage)
                ForEach(personas) { persona in
                    Text("\(persona.icon) \(persona.name)").tag(persona)
                }
            }
            
            Text("coach_note".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    /// アプリ情報セクション
    private var appInfoSection: some View {
        Section(header: Text("app_info".localized)) {
            // バージョン情報
            HStack {
                Text("version".localized)
                Spacer()
                Text(AppConfig.appVersion)
                    .foregroundColor(.secondary)
            }
            
            // 利用規約リンク
            Link("terms".localized, destination: termsURL)
            
            // プライバシーポリシーリンク
            Link("privacy".localized, destination: privacyURL)
        }
    }
    
    /// 利用規約URL
    private var termsURL: URL {
        // TODO: 実際のURLに置き換える
        URL(string: "https://example.com/terms")!
    }
    
    /// プライバシーポリシーURL
    private var privacyURL: URL {
        // TODO: 実際のURLに置き換える
        URL(string: "https://example.com/privacy")!
    }
}
