import Foundation

// MARK: - Badge Generator

/// 決定論的バッジ生成
/// v1.0 ゴールドスタンダード（LLMに依存しない）
struct BadgeGenerator {

    // MARK: - Score Phase

    private static func getScorePhase(_ score: Int, language: AppLanguage) -> String {
        let phases: [String: (ja: String, en: String)] = [
            "rebuild": (ja: "再構築フェーズ", en: "Rebuild Phase"),
            "lost": (ja: "迷走中", en: "Finding Your Way"),
            "growing": (ja: "成長途中", en: "Growing"),
            "rising": (ja: "伸び盛り", en: "On the Rise"),
        ]

        let phase: String
        if score < 60 {
            phase = "rebuild"
        } else if score < 70 {
            phase = "lost"
        } else if score < 80 {
            phase = "growing"
        } else {
            phase = "rising"
        }

        let p = phases[phase]!
        return language == .japanese ? p.ja : p.en
    }

    // MARK: - Weakness Word

    private static func getWeaknessWord(_ key: MetricKey, language: AppLanguage, variant: Int) -> String {
        let words: [MetricKey: (ja: [String], en: [String])] = [
            .swingPath: (
                ja: ["スライサー", "フッカー", "プッシャー", "フェード量産機", "ドロー志望者"],
                en: ["Slicer", "Hooker", "Pusher", "Fade Machine", "Draw Seeker"]
            ),
            .spineAngle: (
                ja: ["軸探しゴルファー", "上体暴れ屋", "前傾キープ挑戦中"],
                en: ["Axis Seeker", "Upper Body Rebel", "Spine Angle Challenger"]
            ),
            .earlyExtension: (
                ja: ["伸び上がり探検家", "ヒップダンサー", "重心迷子"],
                en: ["Early Extender", "Hip Dancer", "Weight Shift Wanderer"]
            ),
            .headMovement: (
                ja: ["ヘッドアップ予備軍", "目線の旅人", "高さ調整中"],
                en: ["Head Up Candidate", "Eye Level Traveler", "Height Adjuster"]
            ),
            .handPosition: (
                ja: ["ハンドリフター", "手元浮き屋", "グリップ探求者"],
                en: ["Hand Lifter", "Grip Floater", "Grip Seeker"]
            ),
            .tempo: (
                ja: ["打ち急ぎ屋", "せっかちゴルファー", "リズム探求中"],
                en: ["Quick Swinger", "Impatient Golfer", "Rhythm Seeker"]
            ),
        ]

        let list = language == .japanese ? words[key]!.ja : words[key]!.en
        return list[variant % list.count]
    }

    // MARK: - Play Word

    private static func getPlayWord(language: AppLanguage, variant: Int) -> String {
        let words: (ja: [String], en: [String]) = (
            ja: ["戦士", "旅人", "挑戦者", "研究家", "候補生", "予備軍"],
            en: ["Warrior", "Traveler", "Challenger", "Researcher", "Candidate", "Recruit"]
        )

        let list = language == .japanese ? words.ja : words.en
        return list[variant % list.count]
    }

    // MARK: - Special Pools

    private static func getExcellentBadge(language: AppLanguage, variant: Int) -> String {
        let badges: (ja: [String], en: [String]) = (
            ja: [
                "安定感の持ち主",
                "型を持つゴルファー",
                "再現性マスター",
                "今日の完成形",
                "本日のベストスイング"
            ],
            en: [
                "Master of Consistency",
                "Golfer with Style",
                "Repeatability Master",
                "Today's Perfection",
                "Today's Best Swing"
            ]
        )

        let list = language == .japanese ? badges.ja : badges.en
        return list[variant % list.count]
    }

    private static func getAlmostThereBadge(language: AppLanguage, variant: Int) -> String {
        let badges: (ja: [String], en: [String]) = (
            ja: [
                "覚醒前夜ゴルファー",
                "仕上がり寸前の挑戦者",
                "あと一手の完成形",
                "ブレークスルー待ち",
                "あと一歩のゴルファー"
            ],
            en: [
                "On the Verge of Breakthrough",
                "Almost Complete Challenger",
                "One Step Away",
                "Waiting for Breakthrough",
                "Almost There Golfer"
            ]
        )

        let list = language == .japanese ? badges.ja : badges.en
        return list[variant % list.count]
    }

    // MARK: - Main Generate Method

    /// バッジを生成
    /// - Parameters:
    ///   - score: スコア（0-100）
    ///   - topIssueKey: 最も問題のある項目のキー（全goodの場合はnil）
    ///   - metaMode: メタモード
    ///   - language: 言語
    ///   - variant: バリエーション番号（被り防止用）
    /// - Returns: バッジ名
    static func generate(
        score: Int,
        topIssueKey: MetricKey?,
        metaMode: MetaMode,
        language: AppLanguage,
        variant: Int = 0
    ) -> String {
        // 特別モード用バッジ
        switch metaMode {
        case .excellent:
            return getExcellentBadge(language: language, variant: variant)
        case .almostThere:
            return getAlmostThereBadge(language: language, variant: variant)
        case .rebuild, .normal:
            break
        }

        // 通常/REBUILDモード
        guard let key = topIssueKey else {
            return language == .japanese ? "成長途中のゴルファー" : "Growing Golfer"
        }

        let weaknessWord = getWeaknessWord(key, language: language, variant: variant)
        let phaseWord = getScorePhase(score, language: language)
        let playWord = getPlayWord(language: language, variant: variant)

        // 日本語: "スライサー成長途中の戦士"
        // 英語: "Slicer - Growing Warrior"
        if language == .japanese {
            return "\(weaknessWord)\(phaseWord)の\(playWord)"
        } else {
            return "\(weaknessWord) - \(phaseWord) \(playWord)"
        }
    }
}
