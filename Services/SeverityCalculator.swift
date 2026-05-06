import Foundation

// MARK: - Severity Types

enum Severity: String, Codable {
    case good = "good"
    case ok = "ok"
    case bad = "bad"
}

enum MetaMode: String {
    case excellent = "EXCELLENT"
    case almostThere = "ALMOST_THERE"
    case rebuild = "REBUILD"
    case normal = "NORMAL"
}

enum MetricKey: String, CaseIterable, Codable {
    case spineAngle = "spine_angle"
    case tempo = "tempo"
    case swingPath = "swing_path"
    case headMovement = "head_movement"
    case handPosition = "hand_position"
    case earlyExtension = "early_extension"
    
    var displayNameJa: String {
        switch self {
        case .spineAngle: return "前傾キープ"
        case .tempo: return "切り返しリズム"
        case .swingPath: return "スイング軌道"
        case .headMovement: return "頭の安定感"
        case .handPosition: return "インパクト時の手元"
        case .earlyExtension: return "腰の伸び上がり"
        }
    }
    
    var displayNameEn: String {
        switch self {
        case .spineAngle: return "Spine Angle"
        case .tempo: return "Transition Timing"
        case .swingPath: return "Swing Path"
        case .headMovement: return "Head Stability"
        case .handPosition: return "Hand Position"
        case .earlyExtension: return "Hip Extension"
        }
    }
    
    func displayName(for language: AppLanguage) -> String {
        switch language {
        case .japanese: return displayNameJa
        case .english: return displayNameEn
        }
    }
}

// MARK: - Ranked Item

struct ItemRanked: Codable {
    let key: MetricKey
    let displayName: String
    let severity: Severity
    let metrics: [String: Double]
    let itemScore: Int
    
    enum CodingKeys: String, CodingKey {
        case key
        case displayName = "display_name"
        case severity
        case metrics
        case itemScore = "item_score"
    }
    
    static func calculateItemScore(from severity: Severity, normalizedDeviation: Double? = nil) -> Int {
        let rawD = min(1.0, max(0.0, normalizedDeviation ?? 0.5))
        let d = 0.1 + rawD * 0.8
        let score: Double
        switch severity {
        case .good: score = 97.0 - 22.0 * d
        case .ok: score = 72.0 - 25.0 * d
        case .bad: score = 42.0 - 37.0 * d
        }
        return Int(max(0, min(100, score.rounded())))
    }
}

// MARK: - Severity Calculator

struct SeverityCalculator {
    private struct Thresholds {
        let goodMax: Double
        let okMax: Double
    }
    
    private static let thresholds: [MetricKey: Thresholds] = [
        .spineAngle: Thresholds(goodMax: 3.0, okMax: 6.0),
        .tempo: Thresholds(goodMax: 0.0, okMax: 0.0),
        .swingPath: Thresholds(goodMax: 3.0, okMax: 7.0),
        .headMovement: Thresholds(goodMax: 0.10, okMax: 0.20),
        .handPosition: Thresholds(goodMax: 0.10, okMax: 0.20),
        .earlyExtension: Thresholds(goodMax: 0.10, okMax: 0.20),
    ]
    
    static func calculate(_ key: MetricKey, value: Double) -> Severity {
        if key == .tempo {
            if value >= 2.6 && value <= 3.2 { return .good }
            else if value >= 2.2 && value <= 3.6 { return .ok }
            else { return .bad }
        }
        guard let threshold = thresholds[key] else { return .ok }
        let absValue = abs(value)
        if absValue <= threshold.goodMax { return .good }
        else if absValue <= threshold.okMax { return .ok }
        else { return .bad }
    }
    
    static func calculateAll(from metrics: SwingMetrics, language: AppLanguage) -> [ItemRanked] {
        var items: [(key: MetricKey, value: Double, severity: Severity)] = []
        
        let swingPathValue: Double = {
            switch metrics.swingPathType {
            case "Outside-In": return 8.0
            case "Inside-Out": return -8.0
            case "Straight": return 0.0
            default: return 5.0
            }
        }()
        items.append((key: .swingPath, value: swingPathValue, severity: calculate(.swingPath, value: swingPathValue)))
        items.append((key: .spineAngle, value: metrics.spineAngleDiffDeg, severity: calculate(.spineAngle, value: metrics.spineAngleDiffDeg)))
        items.append((key: .earlyExtension, value: metrics.hipMoveRatio, severity: calculate(.earlyExtension, value: metrics.hipMoveRatio)))
        items.append((key: .headMovement, value: metrics.headMoveY, severity: calculate(.headMovement, value: metrics.headMoveY)))
        items.append((key: .handPosition, value: metrics.handRaiseY, severity: calculate(.handPosition, value: metrics.handRaiseY)))
        items.append((key: .tempo, value: metrics.tempoRatio, severity: calculate(.tempo, value: metrics.tempoRatio)))
        
        let sorted = items.sorted { lhs, rhs in
            let lhsScore = severityScore(lhs.severity)
            let rhsScore = severityScore(rhs.severity)
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            return abs(lhs.value) > abs(rhs.value)
        }
        
        return sorted.map { item in
            let normalizedDev = normalizeDeviation(key: item.key, value: item.value, severity: item.severity)
            let score = ItemRanked.calculateItemScore(from: item.severity, normalizedDeviation: normalizedDev)
            return ItemRanked(key: item.key, displayName: item.key.displayName(for: language), severity: item.severity, metrics: [item.key.rawValue: item.value], itemScore: score)
        }
    }
    
    private static func normalizeDeviation(key: MetricKey, value: Double, severity: Severity) -> Double {
        guard let threshold = thresholds[key] else {
            if key == .tempo { return normalizeTempoDeviation(value: value, severity: severity) }
            return 0.5
        }
        let absValue = abs(value)
        switch severity {
        case .good: return min(1.0, absValue / max(0.01, threshold.goodMax))
        case .ok:
            let range = threshold.okMax - threshold.goodMax
            return min(1.0, max(0.0, (absValue - threshold.goodMax) / max(0.01, range)))
        case .bad:
            let badMax = threshold.okMax * 2
            return min(1.0, max(0.0, (absValue - threshold.okMax) / max(0.01, badMax - threshold.okMax)))
        }
    }
    
    private static func normalizeTempoDeviation(value: Double, severity: Severity) -> Double {
        let deviation = abs(value - 2.9)
        switch severity {
        case .good: return min(1.0, deviation / 0.3)
        case .ok: return min(1.0, max(0.0, (deviation - 0.3) / 0.4))
        case .bad: return min(1.0, max(0.0, (deviation - 0.7) / 0.7))
        }
    }
    
    private static func severityScore(_ severity: Severity) -> Int {
        switch severity { case .bad: return 3; case .ok: return 2; case .good: return 1 }
    }
}

// MARK: - Meta Mode Calculator

struct MetaModeCalculator {
    static func calculate(from items: [ItemRanked]) -> MetaMode {
        let goodCount = items.filter { $0.severity == .good }.count
        let badCount = items.filter { $0.severity == .bad }.count
        if goodCount == 6 { return .excellent }
        else if goodCount == 5 { return .almostThere }
        else if badCount >= 4 { return .rebuild }
        else { return .normal }
    }
}

// MARK: - Score Calculator

struct ScoreCalculator {
    private static let weights: [MetricKey: Double] = [
        .swingPath: 1.25, .spineAngle: 1.20, .earlyExtension: 1.15,
        .tempo: 1.00, .handPosition: 0.85, .headMovement: 0.75
    ]
    private static let penaltyThreshold: Double = 55.0
    private static let penaltyMultiplier: Double = 0.2
    private static let maxPenalty: Double = 8.0
    
    static func calculate(from items: [ItemRanked]) -> Int {
        var weightedSum: Double = 0
        var totalWeight: Double = 0
        var scores: [Double] = []
        for item in items {
            let clampedScore = Double(max(0, min(100, item.itemScore)))
            let weight = weights[item.key] ?? 1.0
            weightedSum += weight * clampedScore
            totalWeight += weight
            scores.append(clampedScore)
        }
        guard totalWeight > 0 else { return calculateFallback(from: items) }
        let baseScore = weightedSum / totalWeight
        let minScore = scores.min() ?? 100
        let penalty: Double = minScore >= penaltyThreshold ? 0 : min(maxPenalty, (penaltyThreshold - minScore) * penaltyMultiplier)
        return max(0, min(100, Int((baseScore - penalty).rounded())))
    }
    
    private static func calculateFallback(from items: [ItemRanked]) -> Int {
        var score: Double = 0
        for item in items {
            switch item.severity {
            case .good: score += 16.67
            case .ok: score += 10.0
            case .bad: score += 5.0
            }
        }
        return min(100, max(0, Int(score.rounded())))
    }
}

// MARK: - Diagnosis Report V2

struct DiagnosisReportV2 {
    let overallBadgeTitle: String
    let overallCardText: String
    let score: Int
    let metaMode: MetaMode
    let details: [DetailItemV2]
    let itemsRanked: [ItemRanked]
    
    func getDetail(for key: MetricKey) -> DetailItemV2? { details.first { $0.key == key.rawValue } }
    func getItemRanked(for key: MetricKey) -> ItemRanked? { itemsRanked.first { $0.key == key } }
    
    func toDiagnosisReport() -> DiagnosisReport {
        let diagnosisItems = details.enumerated().map { (index, detail) -> DiagnosisItem in
            let itemRanked = index < itemsRanked.count ? itemsRanked[index] : nil
            let severity = itemRanked?.severity ?? .ok
            let severityValue: Double = severity == .bad ? 8.0 : severity == .ok ? 5.0 : 2.0
            let itemKey = itemRanked?.key.rawValue ?? detail.key
            return DiagnosisItem(
                key: itemKey,
                title: itemRanked?.displayName ?? detail.key,
                judgmentTitle: detail.judgmentTitle,
                itemScore: itemRanked?.itemScore,
                status: severity == .bad ? "Bad" : severity == .ok ? "Check" : "Good",
                severity: severityValue,
                visualizationValue: 0,
                comment: detail.detailText,
                detailKeyPhrases: [],
                isTop2: index < 2,
                drill: DiagnosisItem.Drill(
                    title: detail.drillTitle,
                    description: detail.drillText,
                    drillKeyPhrases: []
                )
            )
        }
        let badCheckItems = diagnosisItems.filter { $0.status == "Bad" || $0.status == "Check" }
        let drillsToShow: [String]
        if badCheckItems.count >= 2 { drillsToShow = diagnosisItems.filter { $0.isTop2 }.map { $0.key } }
        else if badCheckItems.count == 1 { drillsToShow = [badCheckItems[0].key] }
        else { drillsToShow = [] }
        return DiagnosisReport(
            coachComment: "", overallSummary: overallCardText, totalScore: score,
            swingRank: metaMode.rawValue, swingTypeName: overallBadgeTitle,
            diagnosisItems: diagnosisItems, drillsToShow: drillsToShow, drillSectionMessage: ""
        )
    }
}
