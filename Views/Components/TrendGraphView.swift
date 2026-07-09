import SwiftUI
import Charts

// MARK: - Graph Types

/// グラフの種類
enum TrendGraphType: Int, CaseIterable, Identifiable {
    case totalScore = 0
    case spineAngle
    case tempo
    case swingPath
    case headMovement
    case handPosition
    case earlyExtension
    
    var id: Int { rawValue }
    
    /// 言語対応のタイトルを取得
    var title: String {
        let key: String
        switch self {
        case .totalScore: key = "metric_total_score"
        case .spineAngle: key = "metric_spine_angle"
        case .tempo: key = "metric_tempo"
        case .swingPath: key = "metric_swing_path"
        case .headMovement: key = "metric_head_movement"
        case .handPosition: key = "metric_hand_position"
        case .earlyExtension: key = "metric_early_extension"
        }
        return key.localized
    }
    
    var metricKey: String? {
        switch self {
        case .totalScore: return nil
        case .spineAngle: return "spine_angle"
        case .tempo: return "tempo"
        case .swingPath: return "swing_path"
        case .headMovement: return "head_movement"
        case .handPosition: return "hand_position"
        case .earlyExtension: return "early_extension"
        }
    }
    
    var color: Color {
        switch self {
        case .totalScore: return Theme.accent
        case .spineAngle: return Theme.forestGreen
        case .tempo: return Theme.championshipGold
        case .swingPath: return Theme.error
        case .headMovement: return Color.purple
        case .handPosition: return Color.orange
        case .earlyExtension: return Color.cyan
        }
    }
}

// MARK: - Data Point

/// グラフ用データポイント
struct TrendDataPoint: Identifiable {
    let id = UUID()
    let index: Int        // レポート出力回（1, 2, 3...）
    let score: Int        // スコア（0-100）
    let date: Date        // 参考用の日付
}

// MARK: - TrendGraphView (Premium)

/// スコア推移グラフビュー（Premium限定）
/// - 総合スコアと各詳細項目のスコア推移を左右スワイプで切り替え表示
/// - 横軸はレポート出力回数ベース
struct TrendGraphView: View {
    let analyses: [SwingAnalysis]
    
    @State private var currentGraphIndex: Int = 0
    
    /// 現在選択中のグラフタイプ
    private var currentGraphType: TrendGraphType {
        TrendGraphType(rawValue: currentGraphIndex) ?? .totalScore
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー（タイトル + インジケーター）
            headerView
            
            // データが2件未満の場合はグラフを表示できない
            if analyses.count < 2 {
                emptyStateView
            } else {
                // スワイプ可能なグラフ
                graphTabView
                
                // ページインジケーター
                pageIndicator
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 16) {
            // 左ボタン
            Button {
                if currentGraphIndex > 0 {
                    currentGraphIndex -= 1
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundColor(currentGraphIndex > 0 ? Theme.accent : Theme.textTertiary.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(currentGraphType.title)
                    .font(.headline)
                    .foregroundColor(currentGraphType.color)
                
                Text("\(currentGraphIndex + 1) / \(TrendGraphType.allCases.count)")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            // 右ボタン
            Button {
                if currentGraphIndex < TrendGraphType.allCases.count - 1 {
                    currentGraphIndex += 1
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(currentGraphIndex < TrendGraphType.allCases.count - 1 ? Theme.accent : Theme.textTertiary.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        Text("graph_data_insufficient".localized)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .background(Theme.surface.opacity(0.3))
            .cornerRadius(12)
            .padding(.horizontal)
    }
    
    // MARK: - Graph TabView
    
    private var graphTabView: some View {
        // TabViewではなく、選択されたグラフのみ表示（スワイプ競合回避）
        SingleTrendChart(
            dataPoints: getDataPoints(for: currentGraphType),
            graphType: currentGraphType
        )
        .id(currentGraphIndex) // アニメーション用
        .transition(.opacity)
        .frame(height: 170)
    }
    
    // MARK: - Page Indicator
    
    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(TrendGraphType.allCases) { graphType in
                Circle()
                    .fill(currentGraphIndex == graphType.rawValue ? graphType.color : Theme.textTertiary.opacity(0.5))
                    .frame(width: currentGraphIndex == graphType.rawValue ? 8 : 6,
                           height: currentGraphIndex == graphType.rawValue ? 8 : 6)
                    .animation(.easeInOut(duration: 0.2), value: currentGraphIndex)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Data Extraction
    
    /// 指定されたグラフタイプのデータポイントを取得
    private func getDataPoints(for graphType: TrendGraphType) -> [TrendDataPoint] {
        // 古い順に並べ替えて、インデックス（回数）を付与
        let sortedAnalyses = analyses.sorted { $0.date < $1.date }
        
        var points: [TrendDataPoint] = []
        
        for (index, analysis) in sortedAnalyses.enumerated() {
            guard let report = analysis.diagnosisReport else { continue }
            
            let score: Int
            if graphType == .totalScore {
                score = report.totalScore
            } else if let key = graphType.metricKey {
                // 各項目のスコアを取得
                score = getItemScore(from: report, key: key)
            } else {
                continue
            }
            
            points.append(TrendDataPoint(
                index: index + 1,  // 1から始まる回数
                score: score,
                date: analysis.date
            ))
        }
        
        // 直近10件に制限
        return Array(points.suffix(10))
    }
    
    /// DiagnosisReportから特定の項目のスコアを取得
    /// - Note: itemScoreがあればそれを使用、なければstatusからフォールバック計算
    private func getItemScore(from report: DiagnosisReport, key: String) -> Int {
        guard let item = report.diagnosisItems.first(where: { $0.key == key }) else {
            return 50 // 項目が見つからない場合のデフォルト値
        }
        
        // itemScoreがあればそれを返す（新しいデータ）
        if let itemScore = item.itemScore {
            return itemScore
        }
        
        // itemScoreがない場合はstatusから推定（既存データとの互換性）
        switch item.status {
        case "Good": return 85
        case "Check": return 60
        case "Bad": return 25
        default: return 50
        }
    }
}

// MARK: - Single Trend Chart

/// 個別のトレンドチャート（インタラクティブ）
private struct SingleTrendChart: View {
    let dataPoints: [TrendDataPoint]
    let graphType: TrendGraphType
    
    /// 選択中のデータポイント
    @State private var selectedPoint: TrendDataPoint?
    
    var body: some View {
        Chart {
            ForEach(dataPoints) { point in
                LineMark(
                    x: .value("回", point.index),
                    y: .value("Score", point.score)
                )
                .foregroundStyle(graphType.color)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                PointMark(
                    x: .value("回", point.index),
                    y: .value("Score", point.score)
                )
                .foregroundStyle(graphType.color)
                .symbolSize(selectedPoint?.index == point.index ? 80 : 40)
            }
            
            // 選択中のポイントにアノテーションを表示（PointMarkに直接）
            if let selected = selectedPoint {
                PointMark(
                    x: .value("回", selected.index),
                    y: .value("Score", selected.score)
                )
                .foregroundStyle(graphType.color)
                .symbolSize(100)
                .annotation(position: .top, alignment: .center, spacing: 4) {
                    Text("\(selected.score)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(graphType.color)
                        .cornerRadius(6)
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        // 言語に応じた表示（#1, #2... or 1回目, 2回目...)
                        Text("#\(intValue)")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateSelection(at: value.location, proxy: proxy, geometry: geometry)
                            }
                            .onEnded { _ in
                                // ドラッグ終了時も選択を維持（タップ後3秒で消える）
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        selectedPoint = nil
                                    }
                                }
                            }
                    )
            }
        }
        .padding(.horizontal)
        .padding(.top, 30) // アノテーション表示用の上部スペース
        .padding(.bottom, 8)
        .background(Theme.surface.opacity(0.3))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    /// タッチ位置から最も近いデータポイントを選択
    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let xPosition = location.x - geometry[proxy.plotAreaFrame].origin.x
        
        guard let index: Int = proxy.value(atX: xPosition) else { return }
        
        // 最も近いデータポイントを検索
        if let point = dataPoints.min(by: { abs($0.index - index) < abs($1.index - index) }) {
            withAnimation(.easeInOut(duration: 0.1)) {
                selectedPoint = point
            }
        }
    }
}

// MARK: - Locked Trend Graph View

/// ロックされたスコア推移グラフビュー（Free/Standard Plan用）
/// - ヘッダー（タイトル+切り替えボタン）は常に表示
/// - グラフ本体のみぼかし表示
struct LockedTrendGraphView: View {
    @State private var currentGraphIndex: Int = 0
    
    /// 現在選択中のグラフタイプ
    private var currentGraphType: TrendGraphType {
        TrendGraphType(rawValue: currentGraphIndex) ?? .totalScore
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー（ぼかし対象外）
            headerView
            
            // グラフ本体（ぼかし+ロック）
            ZStack {
                graphContentView
                    .blur(radius: 4)
                
                lockOverlayView
            }
            
            // ページインジケーター（ぼかし対象外）
            pageIndicator
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Header (Not Blurred)
    
    private var headerView: some View {
        HStack(spacing: 16) {
            // 左ボタン
            Button {
                if currentGraphIndex > 0 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentGraphIndex -= 1
                    }
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundColor(currentGraphIndex > 0 ? Theme.accent : Theme.textTertiary.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // グラフタイトル
            Text(currentGraphType.title)
                .font(.headline)
                .foregroundColor(currentGraphType.color)
            
            Spacer()
            
            // 右ボタン
            Button {
                if currentGraphIndex < TrendGraphType.allCases.count - 1 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentGraphIndex += 1
                    }
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(currentGraphIndex < TrendGraphType.allCases.count - 1 ? Theme.accent : Theme.textTertiary.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Graph Content (Blurred)
    
    private var graphContentView: some View {
        dummyChart
    }
    
    /// ダミーグラフ
    private var dummyChart: some View {
        Chart {
            ForEach(1..<6, id: \.self) { i in
                let score = 40 + i * 10
                LineMark(
                    x: .value("回", i),
                    y: .value("Score", score)
                )
                .foregroundStyle(currentGraphType.color.opacity(0.3))
                .symbol(Circle())
            }
        }
        .chartYScale(domain: 0...100)
        .frame(height: 150)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Theme.surface.opacity(0.3))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Page Indicator (Not Blurred)
    
    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(TrendGraphType.allCases) { graphType in
                Circle()
                    .fill(graphType == currentGraphType ? currentGraphType.color : Theme.textTertiary.opacity(0.5))
                    .frame(width: graphType == currentGraphType ? 8 : 6, height: graphType == currentGraphType ? 8 : 6)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    /// ロックオーバーレイ
    private var lockOverlayView: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundColor(.white)
            Text("premium_feature".localized)
                .font(.headline)
                .foregroundColor(.white)
            Text("graph_premium_locked".localized)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.7))
        .cornerRadius(16)
    }
}
