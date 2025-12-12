import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SwingAnalysis.date, order: .reverse) private var analyses: [SwingAnalysis]
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.edgesIgnoringSafeArea(.all)
                
                List {
                    // トレンドグラフ（プレミアム限定）
                    Section {
                        if subscriptionManager.currentPlan.canViewTrendGraph {
                            TrendGraphView(analyses: analyses)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .padding(.bottom, Theme.Spacing.md.rawValue)
                        } else {
                            LockedTrendGraphView()
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .padding(.bottom, Theme.Spacing.md.rawValue)
                        }
                    }
                    
                    // 履歴リスト
                    Section(header: Text("history_section_title".localized).foregroundColor(Theme.textSecondary)) {
                        if analyses.isEmpty {
                            Text("history_empty".localized)
                                .foregroundColor(Theme.textSecondary)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(analyses) { analysis in
                                ZStack {
                                    // NavigationLinkの矢印を隠すためのハック
                                    NavigationLink(destination: AnalysisDetailView(analysis: analysis)) {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                    
                                    HistoryRow(analysis: analysis)
                                }
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                            .onDelete(perform: deleteItems)
                        }
                    }
                }
                .scrollContentBackground(.hidden) // Listのデフォルト背景を消す
                .listStyle(.plain)
            }
            .navigationTitle("history_title".localized)
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(analyses[index])
            }
        }
    }
}

struct HistoryRow: View {
    let analysis: SwingAnalysis
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md.rawValue) {
            // Score Badge
            ZStack {
                Circle()
                    .fill(Theme.surface)
                    .shadow(color: Color.black.opacity(0.1), radius: 4)
                    .frame(width: 50, height: 50)
                
                if let report = analysis.diagnosisReport {
                    Text("\(report.totalScore)")
                        .typography(.headlineMedium)
                        .foregroundColor(getScoreColor(score: report.totalScore))
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if let report = analysis.diagnosisReport {
                    Text(report.swingTypeName)
                        .typography(.headlineMedium)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(report.swingRank)
                        .typography(.caption)
                        .foregroundColor(Theme.championshipGold)
                } else {
                    Text("analyzing_status".localized)
                        .typography(.headlineMedium)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Text(analysis.date.formatted(date: .numeric, time: .shortened))
                    .typography(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textSecondary.opacity(0.5))
        }
        .padding(Theme.Spacing.md.rawValue)
        .background(Theme.surface.opacity(0.8))
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func getScoreColor(score: Int) -> Color {
        if score >= 80 { return Theme.forestGreen }
        if score >= 60 { return Theme.championshipGold }
        return Theme.error
    }
}

struct AnalysisDetailView: View {
    let analysis: SwingAnalysis
    
    var body: some View {
        DiagnosisView(report: analysis.diagnosisReport, isAnalyzing: false)
    }
}
