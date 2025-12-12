import SwiftUI
import Charts

/// スコア推移グラフビュー
/// - 過去の診断結果からスコアの推移を折れ線グラフで表示します
/// - Note: Swift Chartsフレームワークを使用しています
/// - Important: データが2件未満の場合はグラフではなくメッセージを表示します
struct TrendGraphView: View {
    let analyses: [SwingAnalysis]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("スコア推移")
                .font(.headline)
                .padding(.horizontal)
            
            // データが2件未満の場合はグラフを表示できない
            if analyses.count < 2 {
                emptyStateView
            } else {
                chartView
            }
        }
    }
    
    /// データ不足時の表示
    /// - Note: グラフは2件以上のデータが必要です
    private var emptyStateView: some View {
        Text("データが不足しています")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .background(Theme.surface.opacity(0.3))
            .cornerRadius(12)
            .padding()
    }
    
    /// スコア推移グラフ
    /// - 最新10件のデータを表示し、折れ線グラフとして描画します
    /// - Note: 時系列順に表示するため、reversed()で逆順にしています
    private var chartView: some View {
        Chart {
            // 直近10件のデータを取得して古い順に並べ替える
            ForEach(analyses.prefix(10).reversed()) { analysis in
                // AI診断レポートがある場合のみプロット
                if let report = analysis.diagnosisReport {
                    LineMark(
                        x: .value("Date", analysis.date),
                        y: .value("Score", report.totalScore)
                    )
                    .foregroundStyle(Theme.accent)
                    .symbol(Circle())
                }
            }
        }
        .frame(height: 150)
        .padding()
        .background(Theme.surface.opacity(0.3))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

/// ロックされたスコア推移グラフビュー（Premium機能）
/// - Freeプランユーザーに対して表示するロック画面です
/// - Note: ダミーデータのグラフをぼかし、その上にロックアイコンを重ねて表示します
struct LockedTrendGraphView: View {
    var body: some View {
        ZStack {
            backgroundContentView
                .blur(radius: 3)
            
            lockOverlayView
        }
    }
    
    /// 背景コンテンツ（ぼかし用）
    /// - 実際のグラフっぽい見た目を作るためのダミーデータです
    private var backgroundContentView: some View {
        VStack(alignment: .leading) {
            Text("スコア推移")
                .font(.headline)
                .padding(.horizontal)
            
            dummyChart
        }
    }
    
    /// ダミーグラフ
    /// - ロック画面の背景として表示するダミーデータのグラフです
    /// - Note: 実際のデータではなく、見た目のみを提供します
    private var dummyChart: some View {
        Chart {
            ForEach(0..<5, id: \.self) { i in
                // スコア値を事前に計算（型チェックエラー対策）
                let score = 50 + i * 10
                LineMark(
                    x: .value("Date", i),
                    y: .value("Score", score)
                )
                .foregroundStyle(.gray.opacity(0.3))
            }
        }
        .frame(height: 150)
        .padding()
        .background(Theme.surface.opacity(0.3))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    /// ロックオーバーレイ
    /// - Premium限定機能であることを示すアイコンとメッセージを表示します
    private var lockOverlayView: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundColor(.white)
            Text("Premium限定機能")
                .font(.headline)
                .foregroundColor(.white)
            Text("スコアの推移をグラフで確認できます")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(16)
    }
}
