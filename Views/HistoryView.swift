import SwiftUI
import SwiftData

// MARK: - 診断履歴画面

/// 過去の診断結果一覧を表示する画面
///
/// ## 機能
/// - トレンドグラフ表示（プレミアムユーザー限定）
/// - 診断履歴リスト（スワイプで削除可能）
/// - 各診断結果への詳細遷移
struct HistoryView: View {

    // MARK: - Properties

    /// SwiftDataモデルコンテキスト
    @Environment(\.modelContext) private var modelContext

    /// 診断データ（日付降順でソート）
    @Query(sort: \SwingAnalysis.date, order: .reverse) private var analyses: [SwingAnalysis]

    /// サブスクリプション管理
    @ObservedObject var subscriptionManager = SubscriptionManager.shared

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                Theme.background.edgesIgnoringSafeArea(.all)

                List {
                    trendGraphSection
                    historyListSection
                    bottomSpacerSection
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
            .navigationTitle("history_title".localized)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Sections

    /// トレンドグラフセクション
    private var trendGraphSection: some View {
        Section {
            if subscriptionManager.currentPlan.canViewTrendGraph {
                // プレミアムユーザー：トレンドグラフ表示
                TrendGraphView(analyses: analyses)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .padding(.bottom, Theme.Spacing.md.rawValue)
            } else {
                // 無料ユーザー：ロック状態表示
                LockedTrendGraphView()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .padding(.bottom, Theme.Spacing.md.rawValue)
            }
        }
    }

    /// 診断履歴リストセクション
    private var historyListSection: some View {
        Section(header: sectionHeader) {
            if analyses.isEmpty {
                emptyStateView
            } else {
                ForEach(analyses) { analysis in
                    historyRowWithNavigation(for: analysis)
                }
                .onDelete(perform: deleteItems)
            }
        }
    }

    /// セクションヘッダー
    private var sectionHeader: some View {
        Text("history_section_title".localized)
            .foregroundColor(Theme.textSecondary)
    }

    /// 空状態表示
    private var emptyStateView: some View {
        Text("history_empty".localized)
            .foregroundColor(Theme.textSecondary)
            .listRowBackground(Color.clear)
    }

    /// タブバーとの重なりを防ぐための余白
    private var bottomSpacerSection: some View {
        Section {
            Color.clear
                .frame(height: 80)
                .listRowBackground(Color.clear)
        }
    }

    // MARK: - Components

    /// ナビゲーション付きの履歴行
    private func historyRowWithNavigation(for analysis: SwingAnalysis) -> some View {
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

    // MARK: - Actions

    /// 項目を削除する
    /// - Parameter offsets: 削除対象のインデックス
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(analyses[index])
            }
        }
    }
}

// MARK: - 履歴行コンポーネント

/// 診断履歴の1行分を表示するコンポーネント
struct HistoryRow: View {

    // MARK: - Properties

    /// 表示する診断データ
    let analysis: SwingAnalysis

    // MARK: - Body

    var body: some View {
        HStack(spacing: Theme.Spacing.md.rawValue) {
            scoreBadge
            contentStack
            Spacer()
            chevronIcon
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

    // MARK: - Components

    /// スコアバッジ
    private var scoreBadge: some View {
        ZStack {
            Circle()
                .fill(Theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 4)
                .frame(width: 50, height: 50)

            if let report = analysis.diagnosisReport {
                Text("\(report.totalScore)")
                    .typography(.headlineMedium)
                    .foregroundColor(scoreColor(for: report.totalScore))
            } else {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }

    /// コンテンツスタック（タイトル・日時）
    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let report = analysis.diagnosisReport {
                Text(report.swingTypeName)
                    .typography(.headlineMedium)
                    .foregroundColor(Theme.textPrimary)
            } else {
                Text("analyzing_status".localized)
                    .typography(.headlineMedium)
                    .foregroundColor(Theme.textSecondary)
            }

            Text(analysis.date.formatted(date: .numeric, time: .shortened))
                .typography(.caption)
                .foregroundColor(Theme.textSecondary)
        }
    }

    /// 右矢印アイコン
    private var chevronIcon: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Theme.textSecondary.opacity(0.5))
    }

    // MARK: - Helpers

    /// スコアに応じた色を返す
    /// - Parameter score: スコア値（0-100）
    /// - Returns: 対応する色
    private func scoreColor(for score: Int) -> Color {
        if score >= 80 { return Theme.forestGreen }
        if score >= 60 { return Theme.championshipGold }
        return Theme.error
    }
}

// MARK: - 詳細画面

/// 診断結果の詳細を表示する画面
struct AnalysisDetailView: View {

    /// 表示する診断データ
    let analysis: SwingAnalysis

    var body: some View {
        DiagnosisView(report: analysis.diagnosisReport, isAnalyzing: false)
    }
}
