import SwiftUI

struct SettingsView: View {
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @ObservedObject var usageLimiter = UsageLimiter.shared
    @ObservedObject var languageManager = LanguageManager.shared
    @AppStorage("coachModeId") private var coachModeId: String = "gentle_sister"
    
    private var selectedPersona: Binding<CoachPersona> {
        Binding(
            get: {
                let personas = CoachPersona.availablePersonas(for: languageManager.currentLanguage)
                return personas.first(where: { $0.id == coachModeId }) ?? CoachPersona.standard
            },
            set: { newValue in coachModeId = newValue.id }
        )
    }
    
    var body: some View {
        NavigationView {
            List {
                usageStatusSection
                planSettingsSection
                languageSettingsSection
                coachSettingsSection
                appInfoSection
                bottomSpacerSection
            }
            .navigationTitle("settings_title".localized)
        }
    }
    
    private var usageStatusSection: some View {
        Section(header: Text("usage_status".localized)) {
            HStack {
                Image(systemName: "chart.bar.fill").foregroundColor(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("monthly_usage".localized).font(.subheadline)
                    Text(String(format: "reports_used".localized, usageLimiter.usedCount)).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if usageLimiter.isUnlimited {
                    Text("unlimited".localized).font(.headline).foregroundColor(Theme.forestGreen)
                } else {
                    Text("\(usageLimiter.displayRemainingCount)/\(usageLimiter.monthlyLimit)")
                        .font(.headline)
                        .foregroundColor(usageLimiter.displayRemainingCount > 5 ? Theme.forestGreen : Theme.accentOrange)
                }
            }
            if !usageLimiter.isUnlimited {
                HStack {
                    Image(systemName: "calendar").foregroundColor(Theme.accent)
                    Text("next_reset".localized)
                    Spacer()
                    Text(usageLimiter.getNextResetDate(), style: .date).font(.subheadline).foregroundColor(.secondary)
                }
            }
            HStack {
                Image(systemName: "doc.text.fill").foregroundColor(Theme.accent)
                Text("total_reports".localized)
                Spacer()
                Text(String(format: "reports_count".localized, ReportContextManager.shared.reportCount)).font(.subheadline).foregroundColor(.secondary)
            }
        }
        .onChange(of: subscriptionManager.currentPlan) { _ in usageLimiter.refreshForPlanChange() }
    }
    
    private var planSettingsSection: some View {
        Section(header: Text("plan_settings".localized)) {
            Picker("current_plan".localized, selection: $subscriptionManager.currentPlan) {
                ForEach(SubscriptionPlan.allCases) { plan in
                    HStack { Image(systemName: plan.icon).foregroundColor(plan.color); Text(plan.name) }.tag(plan)
                }
            }.pickerStyle(.navigationLink)
            if subscriptionManager.currentPlan == .free {
                Button(action: { subscriptionManager.upgrade(to: .premium) }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("upgrade_premium".localized).fontWeight(.bold)
                    }
                    .foregroundColor(.white).padding().frame(maxWidth: .infinity)
                    .background(LinearGradient(gradient: Gradient(colors: [.orange, .pink]), startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(10)
                }.listRowInsets(EdgeInsets()).padding()
            }
        }
    }
    
    private var languageSettingsSection: some View {
        Section(header: Text("language_settings".localized)) {
            Picker("language_settings".localized, selection: $languageManager.currentLanguage) {
                ForEach(AppLanguage.allCases) { lang in Text(lang.displayName).tag(lang) }
            }
            .onChange(of: languageManager.currentLanguage) { newValue in languageManager.setLanguage(newValue) }
        }
    }
    
    private var coachSettingsSection: some View {
        Section(header: Text("coach_settings".localized)) {
            Picker("default_coach".localized, selection: selectedPersona) {
                let personas = CoachPersona.availablePersonas(for: languageManager.currentLanguage)
                ForEach(personas) { persona in Text("\(persona.icon) \(persona.name)").tag(persona) }
            }
            Text("coach_note".localized).font(.caption).foregroundColor(.secondary)
        }
    }
    
    private var appInfoSection: some View {
        Section(header: Text("app_info".localized)) {
            HStack { Text("version".localized); Spacer(); Text(AppConfig.appVersion).foregroundColor(.secondary) }
            Link("terms".localized, destination: URL(string: "https://nouza888.github.io/golfscan-ai-legal/terms.html")!)
            Link("privacy".localized, destination: URL(string: "https://nouza888.github.io/golfscan-ai-legal/")!)
        }
    }
    
    private var bottomSpacerSection: some View {
        Section { Color.clear.frame(height: 80).listRowBackground(Color.clear) }
    }
}
