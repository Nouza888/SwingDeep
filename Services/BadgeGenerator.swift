import Foundation

struct BadgeGenerator {
    private static func getScorePhase(_ score: Int, language: AppLanguage) -> String {
        let phases: [String: (ja: String, en: String)] = [
            "rebuild": (ja: "\u518D\u69CB\u7BC9\u30D5\u30A7\u30FC\u30BA", en: "Rebuild Phase"),
            "lost": (ja: "\u8FF7\u8D70\u4E2D", en: "Finding Your Way"),
            "growing": (ja: "\u6210\u9577\u9014\u4E2D", en: "Growing"),
            "rising": (ja: "\u4F38\u3073\u76DB\u308A", en: "On the Rise"),
        ]
        let phase: String
        if score < 60 { phase = "rebuild" }
        else if score < 70 { phase = "lost" }
        else if score < 80 { phase = "growing" }
        else { phase = "rising" }
        let p = phases[phase]!
        return language == .japanese ? p.ja : p.en
    }
    
    private static func getWeaknessWord(_ key: MetricKey, language: AppLanguage, variant: Int) -> String {
        let words: [MetricKey: (ja: [String], en: [String])] = [
            .swingPath: (ja: ["\u30B9\u30E9\u30A4\u30B5\u30FC", "\u30D5\u30C3\u30AB\u30FC", "\u30D7\u30C3\u30B7\u30E3\u30FC", "\u30D5\u30A7\u30FC\u30C9\u91CF\u7523\u6A5F", "\u30C9\u30ED\u30FC\u5FD7\u671B\u8005"], en: ["Slicer", "Hooker", "Pusher", "Fade Machine", "Draw Seeker"]),
            .spineAngle: (ja: ["\u8EF8\u63A2\u3057\u30B4\u30EB\u30D5\u30A1\u30FC", "\u4E0A\u4F53\u66B4\u308C\u5C4B", "\u524D\u50BE\u30AD\u30FC\u30D7\u6311\u6226\u4E2D"], en: ["Axis Seeker", "Upper Body Rebel", "Spine Angle Challenger"]),
            .earlyExtension: (ja: ["\u4F38\u3073\u4E0A\u304C\u308A\u63A2\u691C\u5BB6", "\u30D2\u30C3\u30D7\u30C0\u30F3\u30B5\u30FC", "\u91CD\u5FC3\u8FF7\u5B50"], en: ["Early Extender", "Hip Dancer", "Weight Shift Wanderer"]),
            .headMovement: (ja: ["\u30D8\u30C3\u30C9\u30A2\u30C3\u30D7\u4E88\u5099\u8ECD", "\u76EE\u7DDA\u306E\u65C5\u4EBA", "\u9AD8\u3055\u8ABF\u6574\u4E2D"], en: ["Head Up Candidate", "Eye Level Traveler", "Height Adjuster"]),
            .handPosition: (ja: ["\u30CF\u30F3\u30C9\u30EA\u30D5\u30BF\u30FC", "\u624B\u5143\u6D6E\u304D\u5C4B", "\u30B0\u30EA\u30C3\u30D7\u63A2\u6C42\u8005"], en: ["Hand Lifter", "Grip Floater", "Grip Seeker"]),
            .tempo: (ja: ["\u6253\u3061\u6025\u304E\u5C4B", "\u305B\u3063\u304B\u3061\u30B4\u30EB\u30D5\u30A1\u30FC", "\u30EA\u30BA\u30E0\u63A2\u6C42\u4E2D"], en: ["Quick Swinger", "Impatient Golfer", "Rhythm Seeker"]),
        ]
        let list = language == .japanese ? words[key]!.ja : words[key]!.en
        return list[variant % list.count]
    }
    
    private static func getPlayWord(language: AppLanguage, variant: Int) -> String {
        let words: (ja: [String], en: [String]) = (
            ja: ["\u6226\u58EB", "\u65C5\u4EBA", "\u6311\u6226\u8005", "\u7814\u7A76\u5BB6", "\u5019\u88DC\u751F", "\u4E88\u5099\u8ECD"],
            en: ["Warrior", "Traveler", "Challenger", "Researcher", "Candidate", "Recruit"]
        )
        let list = language == .japanese ? words.ja : words.en
        return list[variant % list.count]
    }
    
    private static func getExcellentBadge(language: AppLanguage, variant: Int) -> String {
        let badges: (ja: [String], en: [String]) = (
            ja: ["\u5B89\u5B9A\u611F\u306E\u6301\u3061\u4E3B", "\u578B\u3092\u6301\u3064\u30B4\u30EB\u30D5\u30A1\u30FC", "\u518D\u73FE\u6027\u30DE\u30B9\u30BF\u30FC", "\u4ECA\u65E5\u306E\u5B8C\u6210\u5F62", "\u672C\u65E5\u306E\u30D9\u30B9\u30C8\u30B9\u30A4\u30F3\u30B0"],
            en: ["Master of Consistency", "Golfer with Style", "Repeatability Master", "Today's Perfection", "Today's Best Swing"]
        )
        let list = language == .japanese ? badges.ja : badges.en
        return list[variant % list.count]
    }
    
    private static func getAlmostThereBadge(language: AppLanguage, variant: Int) -> String {
        let badges: (ja: [String], en: [String]) = (
            ja: ["\u899A\u9192\u524D\u591C\u30B4\u30EB\u30D5\u30A1\u30FC", "\u4ED5\u4E0A\u304C\u308A\u5BF8\u524D\u306E\u6311\u6226\u8005", "\u3042\u3068\u4E00\u624B\u306E\u5B8C\u6210\u5F62", "\u30D6\u30EC\u30FC\u30AF\u30B9\u30EB\u30FC\u5F85\u3061", "\u3042\u3068\u4E00\u6B69\u306E\u30B4\u30EB\u30D5\u30A1\u30FC"],
            en: ["On the Verge of Breakthrough", "Almost Complete Challenger", "One Step Away", "Waiting for Breakthrough", "Almost There Golfer"]
        )
        let list = language == .japanese ? badges.ja : badges.en
        return list[variant % list.count]
    }
    
    static func generate(score: Int, topIssueKey: MetricKey?, metaMode: MetaMode, language: AppLanguage, variant: Int = 0) -> String {
        switch metaMode {
        case .excellent: return getExcellentBadge(language: language, variant: variant)
        case .almostThere: return getAlmostThereBadge(language: language, variant: variant)
        case .rebuild, .normal: break
        }
        guard let key = topIssueKey else {
            return language == .japanese ? "\u6210\u9577\u9014\u4E2D\u306E\u30B4\u30EB\u30D5\u30A1\u30FC" : "Growing Golfer"
        }
        let weaknessWord = getWeaknessWord(key, language: language, variant: variant)
        let phaseWord = getScorePhase(score, language: language)
        let playWord = getPlayWord(language: language, variant: variant)
        if language == .japanese {
            return "\(weaknessWord)\(phaseWord)\u306E\(playWord)"
        } else {
            return "\(weaknessWord) - \(phaseWord) \(playWord)"
        }
    }
}
