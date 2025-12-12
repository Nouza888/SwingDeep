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
    
    @State private var shareImage: Image?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Theme.background.ignoresSafeArea()
                
                if isAnalyzing {
                    LoadingView()
                } else if let report = report {
                    // Chat Stream
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: Theme.Spacing.lg.rawValue) {
                                // 1. Summary Card (Header, Score, Message, Overall Summary)
                                ChatHeader(report: report, persona: coachPersona)
                                    .padding(.top, Theme.Spacing.md.rawValue)
                                
                                // 5. Diagnosis Items (Attachments)
                                DiagnosisItemsChatSection(
                                    report: report,
                                    subscriptionManager: subscriptionManager,
                                    persona: coachPersona
                                )
                                
                                // Spacer for bottom padding
                                Color.clear.frame(height: Theme.Spacing.xxxl.rawValue)
                            }
                            .padding(.horizontal, Theme.Spacing.base.rawValue)
                        }
                    }
                    .onAppear {
                        generateShareImage()
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
                    if let image = shareImage, let report = report {
                        ShareLink(
                            item: image,
                            subject: Text("GolfScan AI Diagnosis"),
                            message: Text(generateShareHashtags(report: report)),
                            preview: SharePreview("GolfScan AI Diagnosis", image: image)
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Theme.forestGreen)
                        }
                    }
                }
            }
        }
    }
    
    @MainActor
    private func generateShareImage() {
        guard let report = report else { return }
        
        let renderer = ImageRenderer(content:
            ChatHeader(report: report, persona: coachPersona)
                .frame(width: 375) // 固定幅でレンダリング
                .background(Theme.background)
        )
        renderer.scale = UIScreen.main.scale
        
        if let uiImage = renderer.uiImage {
            self.shareImage = Image(uiImage: uiImage)
        }
    }
    
    private func generateShareHashtags(report: DiagnosisReport) -> String {
        return """
        #GolfScanAI #ゴルフ #スイング診断 #\(report.swingTypeName)
        """
    }
}
