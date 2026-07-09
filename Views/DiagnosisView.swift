import SwiftUI

/// 診断結果を表示するレポート画面 - Chat Style
struct DiagnosisView: View {
    @Environment(\.dismiss) var dismiss
    let report: DiagnosisReport?
    let isAnalyzing: Bool

    // コーチのペルソナを取得（レポートがない場合はデフォルト）
    private var coachPersona: CoachPersona {
        // ここでは簡易的に取得。本来はレポートに含まれるべきだが、現状は設定から取得
        // 実際のアプリではレポート生成時のペルソナIDを保存しておくのがベスト
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
                // Background
                Theme.background.ignoresSafeArea()

                if isAnalyzing {
                    LoadingView(personaName: coachPersona.name)
                } else if let report = report {
                    // Chat Stream
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: Theme.Spacing.lg.rawValue) {
                                // 1. Summary Card (Header, Score, Message, Overall Summary)
                                ChatHeader(report: report, persona: coachPersona)
                                    .padding(.top, Theme.Spacing.md.rawValue)

                                // 2. Diagnosis Items (評価コメントのみ、ドリルなし)
                                DiagnosisItemsChatSection(
                                    report: report,
                                    subscriptionManager: subscriptionManager,
                                    persona: coachPersona
                                )

                                // 3. Improvement Drills (0〜2本)
                                ImprovementDrillsSection(
                                    report: report,
                                    subscriptionManager: subscriptionManager
                                )

                                // Spacer for bottom padding
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
                    Button("close".localized) {
                        dismiss()
                    }
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
        return """
        🏌️ GolfScan AI診断結果

        タイプ: \(report.swingTypeName)
        ランク: \(report.swingRank)
        スコア: \(report.totalScore)/100

        💬 \(report.coachComment)

        #GolfScanAI #ゴルフ #スイング診断
        """
    }
}
