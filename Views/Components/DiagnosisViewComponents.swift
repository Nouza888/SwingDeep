import SwiftUI

// MARK: - 診断レポートコンポーネント

/// このファイルには診断レポート画面で使用するコンポーネントが含まれます。
///
/// ## 含まれるコンポーネント
/// - ChatHeader: レポートヘッダー（スコア、タイプ、総評）
/// - DiagnosisItemsChatSection: 診断項目リスト
/// - DiagnosisItemChatCard: 個別診断項目カード
/// - DrillCard: 改善ドリルカード（有料コンテンツ）
/// - LoadingView: ローディング表示
/// - NoDataView: 空状態表示

// MARK: - チャットヘッダー

/// 診断レポートのサマリーカード
///
/// スコア、スイングタイプ、総評を1つのカードにまとめたコンポーネント。
/// SNS共有を意識したデザイン。
struct ChatHeader: View {
    
    // MARK: - Properties
    
    /// 診断レポートデータ
    let report: DiagnosisReport
    
    /// 選択されたコーチペルソナ
    let persona: CoachPersona
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md.rawValue) {
            dateLabel
            scoreBadge
            messageHeader
            overallSummarySection
        }
        .padding(24)
        .background(Theme.background)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal, Theme.Spacing.base.rawValue)
    }
    
    // MARK: - Components
    
    /// 日時ラベル
    private var dateLabel: some View {
        Text(Date().formatted(date: .numeric, time: .shortened))
            .typography(.caption)
            .foregroundColor(Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Theme.secondary.opacity(0.1))
            .cornerRadius(10)
    }
    
    /// スコアバッジ
    private var scoreBadge: some View {
        ZStack {
            // 背景円
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
            
            // スコアテキスト
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
    }
    
    /// メッセージヘッダー
    private var messageHeader: some View {
        Text("\(persona.name)からのレポートが届いています")
            .typography(.caption)
            .fontWeight(.bold)
            .foregroundColor(Theme.textSecondary)
            .padding(.top, 8)
    }
    
    /// 総評セクション（アイコン + 吹き出し）
    private var overallSummarySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm.rawValue) {
            // コーチアイコン（上部左寄せ）
            HStack {
                coachIcon
                Spacer()
            }
            
            // 吹き出し（フル幅）
            speechBubble
        }
    }
    
    /// コーチアイコン
    private var coachIcon: some View {
        ZStack {
            Circle()
                .fill(Color(hex: persona.themeColorHex).opacity(0.1))
                .frame(width: 40, height: 40)
            
            Text(persona.icon)
                .font(.system(size: 24))
        }
        .overlay(
            Circle()
                .stroke(Color(hex: persona.themeColorHex).opacity(0.3), lineWidth: 1)
        )
    }
    
    /// 吹き出し
    private var speechBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(report.overallSummary)
                .typography(.bodyMedium)
                .foregroundColor(Theme.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .chatBubble(isMyMessage: false)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 診断項目セクション

/// 診断項目のチャットセクション
///
/// 診断レポート内の各診断項目をチャット形式で表示。
/// 項目カードとドリルカードを分離して表示。
struct DiagnosisItemsChatSection: View {
    
    // MARK: - Properties
    
    /// 診断レポートデータ
    let report: DiagnosisReport
    
    /// サブスクリプション管理
    let subscriptionManager: SubscriptionManager
    
    /// 選択されたコーチペルソナ
    let persona: CoachPersona
    
    /// severityでソートされた診断項目
    private var sortedItems: [DiagnosisItem] {
        report.diagnosisItems.sorted { $0.severity > $1.severity }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg.rawValue) {
            sectionHeader
            itemsList
        }
    }
    
    // MARK: - Components
    
    /// セクションヘッダー
    private var sectionHeader: some View {
        HStack {
            Spacer()
            Text("detail_analysis".localized)
                .typography(.headlineMedium)
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .padding(.top, 16)
    }
    
    /// 診断項目リスト（評価コメントのみ、ドリルは別セクション）
    private var itemsList: some View {
        ForEach(sortedItems.indices, id: \.self) { index in
            let item = sortedItems[index]
            
            // 評価カードのみ表示（ドリルはImprovementDrillsSectionで表示）
            DiagnosisItemChatCard(item: item, subscriptionManager: subscriptionManager)
                .staggeredAppearance(index: index, total: sortedItems.count)
        }
    }
}

// MARK: - 改善ドリルセクション

/// 改善ドリルセクション（0〜2本）
/// v1.0レポート構成変更: ドリルは詳細項目とは別セクションで表示
struct ImprovementDrillsSection: View {
    
    // MARK: - Properties
    
    let report: DiagnosisReport
    let subscriptionManager: SubscriptionManager
    
    /// 表示すべきドリルを取得
    private var drillsToDisplay: [DiagnosisItem] {
        report.diagnosisItems.filter { item in
            report.drillsToShow.contains(item.key) && item.drill != nil
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg.rawValue) {
            // セクションヘッダー
            sectionHeader
            
            // ドリル数に応じた表示
            if drillsToDisplay.isEmpty {
                // 全Good: メッセージのみ
                allGoodMessage
            } else {
                // 1本のみの場合: 特別メッセージ
                if drillsToDisplay.count == 1 {
                    singleDrillMessage
                }
                
                // ドリルカード表示
                ForEach(drillsToDisplay.indices, id: \.self) { index in
                    let item = drillsToDisplay[index]
                    if let drill = item.drill {
                        // 改善対象ラベルはDrillCard内で表示
                        DrillCard(
                            drill: drill,
                            subscriptionManager: subscriptionManager,
                            targetItemTitle: item.title
                        )
                    }
                }
            }
        }
        .padding(.top, 24)
    }
    
    // MARK: - Components
    
    /// セクションヘッダー
    private var sectionHeader: some View {
        VStack(spacing: 4) {
            Text("improvement_drills_title".localized)
                .typography(.headlineMedium)
                .foregroundColor(Theme.textPrimary)
            
            if !drillsToDisplay.isEmpty {
                Text("improvement_drills_sub".localized)
                    .typography(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    /// 全Goodの場合のメッセージ
    private var allGoodMessage: some View {
        Text(report.drillSectionMessage)
            .typography(.bodyMedium)
            .foregroundColor(Theme.textPrimary)
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Theme.surface)
            .cornerRadius(Theme.cornerRadius)
    }
    
    /// ドリル1本のみの場合のメッセージ
    private var singleDrillMessage: some View {
        Text(report.drillSectionMessage)
            .typography(.bodyMedium)
            .foregroundColor(Theme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.bottom, 8)
    }
}

// MARK: - 診断項目カード

/// 個別の診断項目カード（評価のみ）
struct DiagnosisItemChatCard: View {
    
    // MARK: - Properties
    
    /// 診断項目データ
    let item: DiagnosisItem
    
    /// サブスクリプション管理（スコア表示制御用）
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    /// ステータスに応じた色
    private var statusColor: Color {
        switch item.status {
        case "Good": return .green
        case "Bad": return Theme.error
        case "Check": return Theme.championshipGold
        default: return .gray
        }
    }
    
    /// Premium限定: スコア表示可否
    private var canShowScore: Bool {
        subscriptionManager.currentPlan == .premium
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.base.rawValue) {
            headerRow
            
            // Premium限定: スコア表示（タイトル直下、目立つ位置）
            if canShowScore, let score = item.itemScore {
                scoreView(score: score)
            }
            
            judgmentTitleView
            commentTextWithBold
        }
        .padding(Theme.Spacing.md.rawValue)
        .background(Theme.surface)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, Theme.Spacing.base.rawValue)
    }
    
    // MARK: - Components
    
    /// ヘッダー行（タイトルとステータス）
    private var headerRow: some View {
        HStack {
            // ステータスインジケーター
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            // タイトル
            Text(item.title)
                .typography(.headlineMedium)
                .foregroundColor(Theme.textPrimary)
            
            Spacer()
            
            // ステータスバッジ
            Text(item.status)
                .typography(.caption)
                .foregroundColor(statusColor)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(statusColor.opacity(0.15)))
        }
    }
    
    /// スコア表示（Premium限定）- より目立つデザイン
    private func scoreView(score: Int) -> some View {
        HStack(spacing: 8) {
            Text("Score")
                .typography(.caption)
                .foregroundColor(Theme.textSecondary)
            
            Text("\(score)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(statusColor)
            
            Text("/100")
                .typography(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 4)
    }
    
    /// 一言判定タイトル（LLM生成）
    @ViewBuilder
    private var judgmentTitleView: some View {
        if let judgmentTitle = item.judgmentTitle, !judgmentTitle.isEmpty {
            HStack(spacing: 6) {
                // アクセントライン
                RoundedRectangle(cornerRadius: 2)
                    .fill(statusColor)
                    .frame(width: 3, height: 18)
                
                // 判定タイトル
                Text(judgmentTitle)
                    .typography(.bodyLarge)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor)
            }
            .padding(.vertical, 4)
        }
    }
    
    /// コメントテキスト（キーフレーズを太字化）
    private var commentTextWithBold: some View {
        highlightKeyPhrases(text: item.comment, keyPhrases: item.detailKeyPhrases)
            .typography(.bodyMedium)
            .foregroundColor(Theme.textPrimary)
            .lineSpacing(4)
            .textSelection(.enabled)
    }
    
    /// キーフレーズを太字化してTextを生成
    private func highlightKeyPhrases(text: String, keyPhrases: [String]) -> Text {
        guard !keyPhrases.isEmpty else {
            return Text(text)
        }
        
        var result = Text("")
        var remainingText = text
        
        // 各キーフレーズを順番に検索して太字化
        while !remainingText.isEmpty {
            var foundMatch = false
            
            for phrase in keyPhrases {
                if let range = remainingText.range(of: phrase) {
                    // フレーズの前のテキスト
                    let beforeText = String(remainingText[..<range.lowerBound])
                    if !beforeText.isEmpty {
                        result = result + Text(beforeText)
                    }
                    
                    // 太字フレーズ
                    result = result + Text(phrase).fontWeight(.bold)
                    
                    // 残りのテキストを更新
                    remainingText = String(remainingText[range.upperBound...])
                    foundMatch = true
                    break
                }
            }
            
            // マッチがなければ1文字進める
            if !foundMatch {
                let firstChar = String(remainingText.prefix(1))
                result = result + Text(firstChar)
                remainingText = String(remainingText.dropFirst())
            }
        }
        
        return result
    }
}

// MARK: - ドリルカード

/// 改善ドリルカード（有料コンテンツ）
///
/// プレミアムプラン未加入の場合はロック状態で表示。
struct DrillCard: View {
    
    // MARK: - Properties
    
    /// ドリルデータ
    let drill: DiagnosisItem.Drill
    
    /// サブスクリプション管理
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    /// 改善対象の項目タイトル（カード内に表示）
    var targetItemTitle: String? = nil
    
    /// ロック状態かどうか
    private var isLocked: Bool {
        subscriptionManager.currentPlan == .free
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 背景コンテンツ（ロック時はぼかし）
            drillContent
                .blur(radius: isLocked ? 6 : 0)
                .disabled(isLocked)
            
            // ロックオーバーレイ
            if isLocked {
                lockOverlay
            }
        }
        .padding(.horizontal, Theme.Spacing.base.rawValue)
    }
    
    // MARK: - Components
    
    /// ドリルコンテンツ（アンロック時）
    /// 視線順: 「改善ドリル」→「ドリル名」→「改善対象」→「ドリル内容」
    private var drillContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            drillHeader          // 「改善ドリル」ラベル
            drillTitleView       // ドリル名
            targetItemLabel      // 改善対象ラベル
            drillDescriptionView // ドリル内容
            drillStepsSection
            drillRepsAndToolsSection
            drillNgSection
        }
        .padding(20)
        .background(Theme.forestGreen.opacity(0.05))
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.forestGreen.opacity(0.2), lineWidth: 1)
        )
    }
    
    /// ドリルヘッダー
    private var drillHeader: some View {
        HStack {
            Image(systemName: "figure.golf")
                .foregroundColor(Theme.forestGreen)
                .font(.title3)
            Text("improvement_drill".localized)
                .typography(.caption)
                .fontWeight(.bold)
                .foregroundColor(Theme.forestGreen)
                .textCase(.uppercase)
            
            Spacer()
            
            if let timeSec = drill.timeSec {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(String(format: "drill_time".localized, timeSec / 60))
                }
                .foregroundColor(Theme.textSecondary)
            }
        }
    }
    
    /// ドリルタイトル
    private var drillTitleView: some View {
        Text(drill.title)
            .typography(.headlineMedium)
            .foregroundColor(Theme.textPrimary)
    }
    
    /// 改善対象ラベル（カード内表示、矢印なし）
    @ViewBuilder
    private var targetItemLabel: some View {
        if let title = targetItemTitle {
            HStack(spacing: 4) {
                Text("improvement_target".localized)
                    .typography(.caption)
                    .foregroundColor(Theme.textSecondary)
                Text(title)
                    .typography(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.forestGreen)
            }
        }
    }
    
    /// ドリル説明（キーフレーズ太字対応）
    private var drillDescriptionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            highlightKeyPhrases(text: drill.description, keyPhrases: drill.drillKeyPhrases)
                .typography(.bodyMedium)
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(4)
                .textSelection(.enabled)
        }
    }
    
    /// キーフレーズを太字化してTextを生成
    private func highlightKeyPhrases(text: String, keyPhrases: [String]) -> Text {
        guard !keyPhrases.isEmpty else {
            return Text(text)
        }
        
        var result = Text("")
        var remainingText = text
        
        while !remainingText.isEmpty {
            var foundMatch = false
            
            for phrase in keyPhrases {
                if let range = remainingText.range(of: phrase) {
                    let beforeText = String(remainingText[..<range.lowerBound])
                    if !beforeText.isEmpty {
                        result = result + Text(beforeText)
                    }
                    result = result + Text(phrase).fontWeight(.bold)
                    remainingText = String(remainingText[range.upperBound...])
                    foundMatch = true
                    break
                }
            }
            
            if !foundMatch {
                let firstChar = String(remainingText.prefix(1))
                result = result + Text(firstChar)
                remainingText = String(remainingText.dropFirst())
            }
        }
        
        return result
    }
    
    /// 手順セクション
    @ViewBuilder
    private var drillStepsSection: some View {
        if let steps = drill.steps, !steps.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("drill_steps".localized)
                    .typography(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    drillStepRow(index: index, step: step)
                }
            }
            .padding(.top, 8)
        }
    }
    
    /// 手順の1行
    private func drillStepRow(index: Int, step: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(index + 1)")
                .typography(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Theme.forestGreen)
                .clipShape(Circle())
            
            Text(step)
                .typography(.caption)
                .foregroundColor(Theme.textSecondary)
        }
    }
    
    /// 回数と道具セクション
    @ViewBuilder
    private var drillRepsAndToolsSection: some View {
        if drill.reps != nil || drill.tools?.isEmpty == false {
            HStack(spacing: 16) {
                if let reps = drill.reps {
                    repsBadge(reps: reps)
                }
                if let tools = drill.tools, !tools.isEmpty {
                    toolsBadge(tools: tools)
                }
            }
            .padding(.top, 4)
        }
    }
    
    /// 回数バッジ
    private func repsBadge(reps: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "repeat")
                .font(.caption)
            Text(reps)
                .typography(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(Theme.forestGreen)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.forestGreen.opacity(0.1))
        .cornerRadius(8)
    }
    
    /// 道具バッジ
    private func toolsBadge(tools: [String]) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.caption)
            Text(tools.joined(separator: ", "))
                .typography(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(Theme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.surface)
        .cornerRadius(8)
    }
    
    /// 注意点セクション
    @ViewBuilder
    private var drillNgSection: some View {
        if let ngList = drill.ng, !ngList.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(Theme.accentOrange)
                    Text("drill_caution".localized)
                        .typography(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.accentOrange)
                }
                
                ForEach(ngList, id: \.self) { ng in
                    Text("× \(ng)")
                        .typography(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(8)
            .background(Theme.accentOrange.opacity(0.1))
            .cornerRadius(8)
            .padding(.top, 4)
        }
    }
    
    /// ロックオーバーレイ
    private var lockOverlay: some View {
        ZStack {
            // 半透明レイヤー
            Color.white.opacity(0.3)
                .cornerRadius(Theme.cornerRadius)
            
            // ロックコンテンツ
            VStack(spacing: 16) {
                Text("🔒")
                    .font(.system(size: 40))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                VStack(spacing: 4) {
                    Text("drill_locked".localized)
                        .typography(.headlineMedium)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("standard_unlock".localized)
                        .typography(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Theme.surface.opacity(0.9))
                .cornerRadius(12)
                
                upgradeButton
            }
            .padding()
        }
    }
    
    /// アップグレードボタン
    private var upgradeButton: some View {
        Button(action: {
            SubscriptionManager.shared.upgrade(to: .premium)
        }) {
            Text("check_plan".localized)
                .typography(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Capsule().fill(Theme.forestGreen))
                .shadow(color: Theme.forestGreen.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - ローディングビュー

/// AI診断中に表示されるローディングインジケーター
struct LoadingView: View {
    var personaName: String = ""
    
    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.japanese.rawValue
    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguage) ?? .japanese
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl.rawValue) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.forestGreen))
                .scaleEffect(1.5)
            
            Text(String(format: "analyzing".localized, personaName.isEmpty ? "AI Coach" : personaName))
                .typography(.headlineMedium)
                .foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - 空状態ビュー

/// 診断レポートが存在しない場合に表示される空状態
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
