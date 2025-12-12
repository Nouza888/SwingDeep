import SwiftUI

// MARK: - チャットコンポーネント

/// 診断レポートのサマリーカード
///
/// スコア、スイングタイプ、総評を1つのカードにまとめたもの。
/// SNS共有を意識したデザイン。
struct ChatHeader: View {
    let report: DiagnosisReport
    let persona: CoachPersona
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md.rawValue) {
            // 1. 日時
            Text(Date().formatted(date: .numeric, time: .shortened))
                .typography(.caption)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Theme.secondary.opacity(0.1))
                .cornerRadius(10)
            
            // 2. スコア表示
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.surface, Theme.surface.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .shadow(color: Theme.accent.opacity(0.2), radius: 15, x: 0, y: 8)
                    .shadow(color: Color.white.opacity(0.5), radius: 5, x: -5, y: -5)
                
                VStack(spacing: 0) {
                    Text(report.swingTypeName)
                        .typography(.headlineMedium)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.accent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .minimumScaleFactor(0.8)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(report.totalScore)")
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Text("/100")
                            .typography(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .padding(.vertical, 8)
            
            // 3. メッセージヘッダー
            Text("\(persona.name)からのレポートが届いています")
                .typography(.caption)
                .fontWeight(.bold)
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 8)
            
            // 4. 総評（アイコン + 吹き出し）
            HStack(alignment: .top, spacing: Theme.Spacing.sm.rawValue) {
                // アイコン
                ZStack {
                    Circle()
                        .fill(Color(hex: persona.themeColorHex).opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Text(persona.icon)
                        .font(.system(size: 32))
                }
                .overlay(
                    Circle()
                        .stroke(Color(hex: persona.themeColorHex).opacity(0.3), lineWidth: 1)
                )
                
                // 吹き出し
                VStack(alignment: .leading, spacing: 8) {
                    Text(report.overallSummary) // 総評を表示
                        .typography(.bodyMedium)
                        .foregroundColor(Theme.textPrimary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Theme.surface)
                .chatBubble(isMyMessage: false)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
        }
        .padding(24)
        .background(Theme.background) // カード内の背景
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal, Theme.Spacing.base.rawValue)
    }
}

// MARK: - 診断項目セクション

/// 診断項目のチャットセクション
///
/// 診断レポート内の各診断項目をチャット形式で表示。
/// 項目カードとドリルカードを分離して表示。
struct DiagnosisItemsChatSection: View {
    let report: DiagnosisReport
    let subscriptionManager: SubscriptionManager
    let persona: CoachPersona
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg.rawValue) {
            // セクションヘッダー
            HStack {
                Spacer()
                Text("詳細分析")
                    .typography(.headlineMedium)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            .padding(.top, 16)
            
            // 診断項目リスト
            ForEach(sortedItems.indices, id: \.self) { index in
                let item = sortedItems[index]
                
                VStack(spacing: Theme.Spacing.md.rawValue) {
                    // 1. 評価カード
                    DiagnosisItemChatCard(item: item)
                    
                    // 2. ドリルカード（ドリルがある場合のみ）
                    if let drill = item.drill {
                        DrillCard(drill: drill, subscriptionManager: subscriptionManager)
                    }
                }
                .staggeredAppearance(index: index, total: sortedItems.count)
            }
        }
    }
    
    /// severityでソートされた診断項目
    private var sortedItems: [DiagnosisItem] {
        report.diagnosisItems.sorted { $0.severity > $1.severity }
    }
}

/// 個別の診断項目カード（評価のみ）
struct DiagnosisItemChatCard: View {
    let item: DiagnosisItem
    
    /// ステータスに応じた色
    private var statusColor: Color {
        switch item.status {
        case "Good": return .green
        case "Bad": return Theme.error
        case "Check": return Theme.championshipGold
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.base.rawValue) {
            // ヘッダー（タイトルとステータス）
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(item.title)
                    .typography(.headlineMedium)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text(item.status)
                    .typography(.caption)
                    .foregroundColor(statusColor)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(statusColor.opacity(0.15)))
            }
            
            // コメント
            Text(item.comment)
                .typography(.bodyMedium)
                .foregroundColor(Theme.textPrimary)
                .lineSpacing(4)
        }
        .padding(20)
        .background(Theme.surface)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, Theme.Spacing.base.rawValue)
    }
}

/// 改善ドリルカード（有料項目）
struct DrillCard: View {
    let drill: DiagnosisItem.Drill
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        ZStack {
            // 背景のコンテンツ（ロック時はぼかし）
            unlockedContent
                .blur(radius: subscriptionManager.currentPlan == .free ? 6 : 0)
                .disabled(subscriptionManager.currentPlan == .free)
            
            // ロック時のオーバーレイ
            if subscriptionManager.currentPlan == .free {
                Color.white.opacity(0.3) // ぼかしの上にかける薄いレイヤー
                    .cornerRadius(Theme.cornerRadius)
                
                VStack(spacing: 16) {
                    Text("🔒")
                        .font(.system(size: 40))
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    VStack(spacing: 4) {
                        Text("改善ドリルはロックされています")
                            .typography(.headlineMedium)
                            .foregroundColor(Theme.textPrimary)
                        
                        Text("Standardプラン以上で\nロックが解除されます")
                            .typography(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Theme.surface.opacity(0.9))
                    .cornerRadius(12)
                    
                    Button(action: {
                        SubscriptionManager.shared.upgrade(to: .premium)
                    }) {
                        Text("プランを確認する")
                            .typography(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Theme.forestGreen))
                            .shadow(color: Theme.forestGreen.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                }
                .padding()
            }
        }
        .padding(.horizontal, Theme.Spacing.base.rawValue)
    }
    
    private var unlockedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.golf")
                    .foregroundColor(Theme.forestGreen)
                    .font(.title3)
                Text("改善ドリル")
                    .typography(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.forestGreen)
                    .textCase(.uppercase)
            }
            
            Text(drill.title)
                .typography(.headlineMedium)
                .foregroundColor(Theme.textPrimary)
            
            Divider()
            
            Text(drill.description)
                .typography(.bodyMedium)
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(4)
        }
        .padding(20)
        .background(Theme.forestGreen.opacity(0.05))
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.forestGreen.opacity(0.2), lineWidth: 1)
        )
    }
    
    // lockedContent is no longer used as a separate view, integrated into body with ZStack
}

// MARK: - ローディングと空状態

/// ローディングビュー
///
/// AI診断中に表示されるローディングインジケーター。
struct LoadingView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl.rawValue) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.forestGreen))
                .scaleEffect(1.5)
            
            Text("analyzing".localized)
                .typography(.headlineMedium)
                .foregroundColor(Theme.textSecondary)
        }
    }
}

/// データなしビュー
///
/// 診断レポートが存在しない場合に表示される空状態。
struct NoDataView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl.rawValue) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64, weight: .medium))
                .foregroundColor(Theme.textSecondary)
            
            Text("no_data".localized)
                .typography(.headlineMedium)
                .foregroundColor(Theme.textSecondary)
        }
    }
}
