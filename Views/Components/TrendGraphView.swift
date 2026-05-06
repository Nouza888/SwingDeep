import SwiftUI
import Charts

enum TrendGraphType: Int, CaseIterable, Identifiable {
    case totalScore = 0
    case spineAngle, tempo, swingPath, headMovement, handPosition, earlyExtension
    
    var id: Int { rawValue }
    
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

struct TrendDataPoint: Identifiable {
    let id = UUID()
    let index: Int
    let score: Int
    let date: Date
}

struct TrendGraphView: View {
    let analyses: [SwingAnalysis]
    @State private var currentGraphIndex: Int = 0
    
    private var currentGraphType: TrendGraphType {
        TrendGraphType(rawValue: currentGraphIndex) ?? .totalScore
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            if analyses.count < 2 {
                Text("graph_data_insufficient".localized)
                    .font(.caption).foregroundColor(.secondary)
                    .frame(height: 150).frame(maxWidth: .infinity)
                    .background(Theme.surface.opacity(0.3)).cornerRadius(12).padding(.horizontal)
            } else {
                SingleTrendChart(dataPoints: getDataPoints(for: currentGraphType), graphType: currentGraphType)
                    .id(currentGraphIndex).transition(.opacity).frame(height: 170)
                pageIndicator
            }
        }.padding(.vertical, 8)
    }
    
    private var headerView: some View {
        HStack(spacing: 16) {
            Button { if currentGraphIndex > 0 { currentGraphIndex -= 1 } } label: {
                Image(systemName: "chevron.left.circle.fill").font(.title2)
                    .foregroundColor(currentGraphIndex > 0 ? Theme.accent : Theme.textTertiary.opacity(0.3))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text(currentGraphType.title).font(.headline).foregroundColor(currentGraphType.color)
                Text("\(currentGraphIndex + 1) / \(TrendGraphType.allCases.count)").font(.caption2).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Button { if currentGraphIndex < TrendGraphType.allCases.count - 1 { currentGraphIndex += 1 } } label: {
                Image(systemName: "chevron.right.circle.fill").font(.title2)
                    .foregroundColor(currentGraphIndex < TrendGraphType.allCases.count - 1 ? Theme.accent : Theme.textTertiary.opacity(0.3))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }.padding(.horizontal)
    }
    
    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(TrendGraphType.allCases) { graphType in
                Circle()
                    .fill(currentGraphIndex == graphType.rawValue ? graphType.color : Theme.textTertiary.opacity(0.5))
                    .frame(width: currentGraphIndex == graphType.rawValue ? 8 : 6,
                           height: currentGraphIndex == graphType.rawValue ? 8 : 6)
                    .animation(.easeInOut(duration: 0.2), value: currentGraphIndex)
            }
        }.frame(maxWidth: .infinity)
    }
    
    private func getDataPoints(for graphType: TrendGraphType) -> [TrendDataPoint] {
        let sortedAnalyses = analyses.sorted { $0.date < $1.date }
        var points: [TrendDataPoint] = []
        for (index, analysis) in sortedAnalyses.enumerated() {
            guard let report = analysis.diagnosisReport else { continue }
            let score: Int
            if graphType == .totalScore { score = report.totalScore }
            else if let key = graphType.metricKey { score = getItemScore(from: report, key: key) }
            else { continue }
            points.append(TrendDataPoint(index: index + 1, score: score, date: analysis.date))
        }
        return Array(points.suffix(10))
    }
    
    private func getItemScore(from report: DiagnosisReport, key: String) -> Int {
        guard let item = report.diagnosisItems.first(where: { $0.key == key }) else { return 50 }
        if let itemScore = item.itemScore { return itemScore }
        switch item.status {
        case "Good": return 85; case "Check": return 60; case "Bad": return 25; default: return 50
        }
    }
}

private struct SingleTrendChart: View {
    let dataPoints: [TrendDataPoint]
    let graphType: TrendGraphType
    @State private var selectedPoint: TrendDataPoint?
    
    var body: some View {
        Chart {
            ForEach(dataPoints) { point in
                LineMark(x: .value("回", point.index), y: .value("Score", point.score))
                    .foregroundStyle(graphType.color).lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(x: .value("回", point.index), y: .value("Score", point.score))
                    .foregroundStyle(graphType.color).symbolSize(selectedPoint?.index == point.index ? 80 : 40)
            }
            if let selected = selectedPoint {
                PointMark(x: .value("回", selected.index), y: .value("Score", selected.score))
                    .foregroundStyle(graphType.color).symbolSize(100)
                    .annotation(position: .top, alignment: .center, spacing: 4) {
                        Text("\(selected.score)").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(graphType.color).cornerRadius(6)
                    }
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel { if let intValue = value.as(Int.self) { Text("#\(intValue)").font(.caption2) } }
            }
        }
        .chartYAxis { AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { _ in AxisGridLine(); AxisValueLabel() } }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in updateSelection(at: value.location, proxy: proxy, geometry: geometry) }
                            .onEnded { _ in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation(.easeOut(duration: 0.2)) { selectedPoint = nil }
                                }
                            }
                    )
            }
        }
        .padding(.horizontal).padding(.top, 30).padding(.bottom, 8)
        .background(Theme.surface.opacity(0.3)).cornerRadius(12).padding(.horizontal)
    }
    
    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let xPosition = location.x - geometry[proxy.plotAreaFrame].origin.x
        guard let index: Int = proxy.value(atX: xPosition) else { return }
        if let point = dataPoints.min(by: { abs($0.index - index) < abs($1.index - index) }) {
            withAnimation(.easeInOut(duration: 0.1)) { selectedPoint = point }
        }
    }
}

struct LockedTrendGraphView: View {
    @State private var currentGraphIndex: Int = 0
    private var currentGraphType: TrendGraphType { TrendGraphType(rawValue: currentGraphIndex) ?? .totalScore }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            ZStack {
                dummyChart.blur(radius: 4)
                VStack(spacing: 8) {
                    Image(systemName: "lock.fill").font(.largeTitle).foregroundColor(.white)
                    Text("premium_feature".localized).font(.headline).foregroundColor(.white)
                    Text("graph_premium_locked".localized).font(.caption).foregroundColor(.white.opacity(0.8))
                }.padding(.horizontal, 24).padding(.vertical, 16).background(Color.black.opacity(0.7)).cornerRadius(16)
            }
            pageIndicator
        }.padding(.vertical, 8)
    }
    
    private var headerView: some View {
        HStack(spacing: 16) {
            Button { if currentGraphIndex > 0 { withAnimation(.easeInOut(duration: 0.2)) { currentGraphIndex -= 1 } } } label: {
                Image(systemName: "chevron.left.circle.fill").font(.title2)
                    .foregroundColor(currentGraphIndex > 0 ? Theme.accent : Theme.textTertiary.opacity(0.3))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Spacer()
            Text(currentGraphType.title).font(.headline).foregroundColor(currentGraphType.color)
            Spacer()
            Button { if currentGraphIndex < TrendGraphType.allCases.count - 1 { withAnimation(.easeInOut(duration: 0.2)) { currentGraphIndex += 1 } } } label: {
                Image(systemName: "chevron.right.circle.fill").font(.title2)
                    .foregroundColor(currentGraphIndex < TrendGraphType.allCases.count - 1 ? Theme.accent : Theme.textTertiary.opacity(0.3))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }.padding(.horizontal)
    }
    
    private var dummyChart: some View {
        Chart {
            ForEach(1..<6, id: \.self) { i in
                LineMark(x: .value("回", i), y: .value("Score", 40 + i * 10))
                    .foregroundStyle(currentGraphType.color.opacity(0.3)).symbol(Circle())
            }
        }.chartYScale(domain: 0...100).frame(height: 150)
        .padding(.horizontal).padding(.vertical, 8).background(Theme.surface.opacity(0.3)).cornerRadius(12).padding(.horizontal)
    }
    
    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(TrendGraphType.allCases) { graphType in
                Circle()
                    .fill(graphType == currentGraphType ? currentGraphType.color : Theme.textTertiary.opacity(0.5))
                    .frame(width: graphType == currentGraphType ? 8 : 6, height: graphType == currentGraphType ? 8 : 6)
            }
        }.frame(maxWidth: .infinity)
    }
}
