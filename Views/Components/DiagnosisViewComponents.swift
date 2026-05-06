import SwiftUI

// MARK: - Chat Header

struct ChatHeader: View {
    let report: DiagnosisReport
    let persona: CoachPersona
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md.rawValue) {
            Text(Date().formatted(date: .numeric, time: .shortened))
                .typography(.caption).foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Theme.secondary.opacity(0.1)).cornerRadius(10)
            
            ZStack {
                Circle().fill(LinearGradient(colors: [Theme.surface, Theme.surface.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 140, height: 140)
                    .shadow(color: Theme.accent.opacity(0.2), radius: 15, x: 0, y: 8)
                    .shadow(color: Color.white.opacity(0.5), radius: 5, x: -5, y: -5)
                VStack(spacing: 0) {
                    Text(report.swingTypeName).typography(.headlineMedium).fontWeight(.bold)
                        .foregroundColor(Theme.accent).multilineTextAlignment(.center).padding(.horizontal, 8).minimumScaleFactor(0.8)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(report.totalScore)").font(.system(size: 48, weight: .heavy, design: .rounded)).foregroundColor(Theme.textPrimary)
                        Text("/100").typography(.caption).foregroundColor(Theme.textSecondary)
                    }
                }
            }.padding(.vertical, 8)
            
            Text("\(persona.name)\u{304B}\u{3089}\u{306E}\u{30EC}\u{30DD}\u{30FC}\u{30C8}\u{304C}\u{5C4A}\u{3044}\u{3066}\u{3044}\u{307E}\u{3059}")
                .typography(.caption).fontWeight(.bold).foregroundColor(Theme.textSecondary).padding(.top, 8)
            
            VStack(alignment: .leading, spacing: Theme.Spacing.sm.rawValue) {
                HStack {
                    ZStack {
                        Circle().fill(Color(hex: persona.themeColorHex).opacity(0.1)).frame(width: 40, height: 40)
                        Text(persona.icon).font(.system(size: 24))
                    }.overlay(Circle().stroke(Color(hex: persona.themeColorHex).opacity(0.3), lineWidth: 1))
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(report.overallSummary).typography(.bodyMedium).foregroundColor(Theme.textPrimary)
                        .lineSpacing(4).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface).chatBubble(isMyMessage: false)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
        }
        .padding(24).background(Theme.background).cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white, lineWidth: 2))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal, Theme.Spacing.base.rawValue)
    }
}

// MARK: - Diagnosis Items Chat Section

struct DiagnosisItemsChatSection: View {
    let report: DiagnosisReport
    let subscriptionManager: SubscriptionManager
    let persona: CoachPersona
    
    private var sortedItems: [DiagnosisItem] { report.diagnosisItems.sorted { $0.severity > $1.severity } }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg.rawValue) {
            HStack { Spacer(); Text("detail_analysis".localized).typography(.headlineMedium).foregroundColor(Theme.textSecondary); Spacer() }.padding(.top, 16)
            ForEach(sortedItems.indices, id: \.self) { index in
                DiagnosisItemChatCard(item: sortedItems[index], subscriptionManager: subscriptionManager)
                    .staggeredAppearance(index: index, total: sortedItems.count)
            }
        }
    }
}

// MARK: - Improvement Drills Section

struct ImprovementDrillsSection: View {
    let report: DiagnosisReport
    let subscriptionManager: SubscriptionManager
    
    private var drillsToDisplay: [DiagnosisItem] {
        report.diagnosisItems.filter { item in report.drillsToShow.contains(item.key) && item.drill != nil }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg.rawValue) {
            VStack(spacing: 4) {
                Text("improvement_drills_title".localized).typography(.headlineMedium).foregroundColor(Theme.textPrimary)
                if !drillsToDisplay.isEmpty {
                    Text("improvement_drills_sub".localized).typography(.caption).foregroundColor(Theme.textSecondary)
                }
            }.frame(maxWidth: .infinity)
            
            if drillsToDisplay.isEmpty {
                Text(report.drillSectionMessage).typography(.bodyMedium).foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center).padding().frame(maxWidth: .infinity)
                    .background(Theme.surface).cornerRadius(Theme.cornerRadius)
            } else {
                if drillsToDisplay.count == 1 {
                    Text(report.drillSectionMessage).typography(.bodyMedium).foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center).padding(.horizontal).padding(.bottom, 8)
                }
                ForEach(drillsToDisplay.indices, id: \.self) { index in
                    if let drill = drillsToDisplay[index].drill {
                        DrillCard(drill: drill, subscriptionManager: subscriptionManager, targetItemTitle: drillsToDisplay[index].title)
                    }
                }
            }
        }.padding(.top, 24)
    }
}

// MARK: - Diagnosis Item Chat Card

struct DiagnosisItemChatCard: View {
    let item: DiagnosisItem
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    private var statusColor: Color {
        switch item.status { case "Good": return .green; case "Bad": return Theme.error; case "Check": return Theme.championshipGold; default: return .gray }
    }
    private var canShowScore: Bool { subscriptionManager.currentPlan == .premium }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.base.rawValue) {
            HStack {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(item.title).typography(.headlineMedium).foregroundColor(Theme.textPrimary)
                Spacer()
                Text(item.status).typography(.caption).foregroundColor(statusColor).fontWeight(.bold)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(statusColor.opacity(0.15)))
            }
            if canShowScore, let score = item.itemScore {
                HStack(spacing: 8) {
                    Text("Score").typography(.caption).foregroundColor(Theme.textSecondary)
                    Text("\(score)").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(statusColor)
                    Text("/100").typography(.caption).foregroundColor(Theme.textSecondary)
                }.padding(.vertical, 4)
            }
            if let judgmentTitle = item.judgmentTitle, !judgmentTitle.isEmpty {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(statusColor).frame(width: 3, height: 18)
                    Text(judgmentTitle).typography(.bodyLarge).fontWeight(.bold).foregroundColor(statusColor)
                }.padding(.vertical, 4)
            }
            highlightKeyPhrases(text: item.comment, keyPhrases: item.detailKeyPhrases)
                .typography(.bodyMedium).foregroundColor(Theme.textPrimary).lineSpacing(4).textSelection(.enabled)
        }
        .padding(Theme.Spacing.md.rawValue).background(Theme.surface).cornerRadius(Theme.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, Theme.Spacing.base.rawValue)
    }
    
    private func highlightKeyPhrases(text: String, keyPhrases: [String]) -> Text {
        guard !keyPhrases.isEmpty else { return Text(text) }
        var result = Text(""); var remainingText = text
        while !remainingText.isEmpty {
            var foundMatch = false
            for phrase in keyPhrases {
                if let range = remainingText.range(of: phrase) {
                    let beforeText = String(remainingText[..<range.lowerBound])
                    if !beforeText.isEmpty { result = result + Text(beforeText) }
                    result = result + Text(phrase).fontWeight(.bold)
                    remainingText = String(remainingText[range.upperBound...]); foundMatch = true; break
                }
            }
            if !foundMatch { result = result + Text(String(remainingText.prefix(1))); remainingText = String(remainingText.dropFirst()) }
        }
        return result
    }
}

// MARK: - Drill Card

struct DrillCard: View {
    let drill: DiagnosisItem.Drill
    @ObservedObject var subscriptionManager: SubscriptionManager
    var targetItemTitle: String? = nil
    private var isLocked: Bool { subscriptionManager.currentPlan == .free }
    
    var body: some View {
        ZStack {
            drillContent.blur(radius: isLocked ? 6 : 0).disabled(isLocked)
            if isLocked { lockOverlay }
        }.padding(.horizontal, Theme.Spacing.base.rawValue)
    }
    
    private var drillContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.golf").foregroundColor(Theme.forestGreen).font(.title3)
                Text("improvement_drill".localized).typography(.caption).fontWeight(.bold).foregroundColor(Theme.forestGreen).textCase(.uppercase)
                Spacer()
                if let timeSec = drill.timeSec {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.caption)
                        Text(String(format: "drill_time".localized, timeSec / 60))
                    }.foregroundColor(Theme.textSecondary)
                }
            }
            Text(drill.title).typography(.headlineMedium).foregroundColor(Theme.textPrimary)
            if let title = targetItemTitle {
                HStack(spacing: 4) {
                    Text("improvement_target".localized).typography(.caption).foregroundColor(Theme.textSecondary)
                    Text(title).typography(.caption).fontWeight(.semibold).foregroundColor(Theme.forestGreen)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                highlightKeyPhrases(text: drill.description, keyPhrases: drill.drillKeyPhrases)
                    .typography(.bodyMedium).foregroundColor(Theme.textSecondary).lineSpacing(4).textSelection(.enabled)
            }
            if let steps = drill.steps, !steps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("drill_steps".localized).typography(.caption).fontWeight(.bold).foregroundColor(Theme.textPrimary)
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)").typography(.caption).fontWeight(.bold).foregroundColor(.white)
                                .frame(width: 20, height: 20).background(Theme.forestGreen).clipShape(Circle())
                            Text(step).typography(.caption).foregroundColor(Theme.textSecondary)
                        }
                    }
                }.padding(.top, 8)
            }
            if drill.reps != nil || drill.tools?.isEmpty == false {
                HStack(spacing: 16) {
                    if let reps = drill.reps {
                        HStack(spacing: 4) { Image(systemName: "repeat").font(.caption); Text(reps).typography(.caption).fontWeight(.medium) }
                            .foregroundColor(Theme.forestGreen).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Theme.forestGreen.opacity(0.1)).cornerRadius(8)
                    }
                    if let tools = drill.tools, !tools.isEmpty {
                        HStack(spacing: 4) { Image(systemName: "wrench.and.screwdriver").font(.caption); Text(tools.joined(separator: ", ")).typography(.caption).fontWeight(.medium) }
                            .foregroundColor(Theme.textSecondary).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Theme.surface).cornerRadius(8)
                    }
                }.padding(.top, 4)
            }
            if let ngList = drill.ng, !ngList.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundColor(Theme.accentOrange)
                        Text("drill_caution".localized).typography(.caption).fontWeight(.bold).foregroundColor(Theme.accentOrange)
                    }
                    ForEach(ngList, id: \.self) { ng in
                        Text("\u{00D7} \(ng)").typography(.caption).foregroundColor(Theme.textSecondary)
                    }
                }.padding(8).background(Theme.accentOrange.opacity(0.1)).cornerRadius(8).padding(.top, 4)
            }
        }
        .padding(20).background(Theme.forestGreen.opacity(0.05)).cornerRadius(Theme.cornerRadius)
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.forestGreen.opacity(0.2), lineWidth: 1))
    }
    
    private func highlightKeyPhrases(text: String, keyPhrases: [String]) -> Text {
        guard !keyPhrases.isEmpty else { return Text(text) }
        var result = Text(""); var remainingText = text
        while !remainingText.isEmpty {
            var foundMatch = false
            for phrase in keyPhrases {
                if let range = remainingText.range(of: phrase) {
                    let beforeText = String(remainingText[..<range.lowerBound])
                    if !beforeText.isEmpty { result = result + Text(beforeText) }
                    result = result + Text(phrase).fontWeight(.bold)
                    remainingText = String(remainingText[range.upperBound...]); foundMatch = true; break
                }
            }
            if !foundMatch { result = result + Text(String(remainingText.prefix(1))); remainingText = String(remainingText.dropFirst()) }
        }
        return result
    }
    
    private var lockOverlay: some View {
        ZStack {
            Color.white.opacity(0.3).cornerRadius(Theme.cornerRadius)
            VStack(spacing: 16) {
                Text("\u{1F512}").font(.system(size: 40)).shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                VStack(spacing: 4) {
                    Text("drill_locked".localized).typography(.headlineMedium).foregroundColor(Theme.textPrimary)
                    Text("standard_unlock".localized).typography(.caption).foregroundColor(Theme.textSecondary).multilineTextAlignment(.center)
                }.padding(.horizontal).padding(.vertical, 8).background(Theme.surface.opacity(0.9)).cornerRadius(12)
                Button(action: { SubscriptionManager.shared.upgrade(to: .premium) }) {
                    Text("check_plan".localized).typography(.caption).fontWeight(.bold).foregroundColor(.white)
                        .padding(.horizontal, 24).padding(.vertical, 10)
                        .background(Capsule().fill(Theme.forestGreen))
                        .shadow(color: Theme.forestGreen.opacity(0.3), radius: 4, x: 0, y: 2)
                }
            }.padding()
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var personaName: String = ""
    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.japanese.rawValue
    private var language: AppLanguage { AppLanguage(rawValue: appLanguage) ?? .japanese }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl.rawValue) {
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Theme.forestGreen)).scaleEffect(1.5)
            Text(String(format: "analyzing".localized, personaName.isEmpty ? "AI Coach" : personaName))
                .typography(.headlineMedium).foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - No Data View

struct NoDataView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl.rawValue) {
            Image(systemName: "doc.text.magnifyingglass").font(.system(size: 64, weight: .medium)).foregroundColor(Theme.textSecondary)
            Text("no_data".localized).typography(.headlineMedium).foregroundColor(Theme.textSecondary)
        }
    }
}
