import SwiftUI

struct DiagnosisView: View {
    @Environment(\.dismiss) var dismiss
    let report: DiagnosisReport?
    let isAnalyzing: Bool
    
    private var coachPersona: CoachPersona {
        let savedId = UserDefaults.standard.string(forKey: "coachModeId") ?? "normal_jp"
        let personas = CoachPersona.availablePersonas(for: LanguageManager.shared.currentLanguage)
        return personas.first(where: { $0.id == savedId }) ?? CoachPersona.standard
    }
    
    init(report: DiagnosisReport?, isAnalyzing: Bool = false) {
        self.report = report
        self.isAnalyzing = isAnalyzing
    }
    
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if isAnalyzing {
                    LoadingView(personaName: coachPersona.name)
                } else if let report = report {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: Theme.Spacing.lg.rawValue) {
                                ChatHeader(report: report, persona: coachPersona)
                                    .padding(.top, Theme.Spacing.md.rawValue)
                                
                                DiagnosisItemsChatSection(
                                    report: report,
                                    subscriptionManager: subscriptionManager,
                                    persona: coachPersona
                                )
                                
                                ImprovementDrillsSection(
                                    report: report,
                                    subscriptionManager: subscriptionManager
                                )
                                
                                Color.clear.frame(height: Theme.Spacing.xxxl.rawValue)
                            }
                            .padding(.horizontal, Theme.Spacing.base.rawValue)
                        }
                    }
                } else {
                    NoDataView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("close".localized) { dismiss() }
                        .typography(.bodyLarge)
                        .foregroundColor(Theme.forestGreen)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let report = report {
                        ShareLink(item: generateShareText(report: report)) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Theme.forestGreen)
                        }
                    }
                }
            }
        }
    }
    
    private func generateShareText(report: DiagnosisReport) -> String {
        """
        \u{1F3CC}\u{FE0F} GolfScan AI\u8A3A\u65AD\u7D50\u679C
        
        \u30BF\u30A4\u30D7: \(report.swingTypeName)
        \u30E9\u30F3\u30AF: \(report.swingRank)
        \u30B9\u30B3\u30A2: \(report.totalScore)/100
        
        \u{1F4AC} \(report.coachComment)
        
        #GolfScanAI #\u30B4\u30EB\u30D5 #\u30B9\u30A4\u30F3\u30B0\u8A3A\u65AD
        """
    }
}
