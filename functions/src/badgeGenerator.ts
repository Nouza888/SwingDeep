/**
 * GolfScan AI - バッジ生成
 * 決定論的バッジ命名（LLMに依存しない）
 */

import { MetaMode, MetricKey } from "./severityThresholds";

/**
 * スコア帯から状態フェーズを取得
 */
function getScorePhase(score: number, locale: string): string {
    const phases: Record<string, Record<string, string>> = {
        rebuild: { ja: "再構築フェーズ", en: "Rebuild Phase" },
        lost: { ja: "迷走中", en: "Finding Your Way" },
        growing: { ja: "成長途中", en: "Growing" },
        rising: { ja: "伸び盛り", en: "On the Rise" },
    };

    let phase: string;
    if (score < 60) {
        phase = "rebuild";
    } else if (score < 70) {
        phase = "lost";
    } else if (score < 80) {
        phase = "growing";
    } else {
        phase = "rising";
    }

    return phases[phase][locale] || phases[phase]["ja"];
}

/**
 * 弱点keyからゴルフ文脈ワードを取得
 */
function getWeaknessWord(
    key: MetricKey,
    locale: string,
    variant: number
): string {
    const words: Record<MetricKey, Record<string, string[]>> = {
        swing_path: {
            ja: ["スライサー", "フッカー", "プッシャー", "フェード量産機", "ドロー志望者"],
            en: ["Slicer", "Hooker", "Pusher", "Fade Machine", "Draw Seeker"],
        },
        spine_angle: {
            ja: ["軸探しゴルファー", "上体暴れ屋", "前傾キープ挑戦中"],
            en: ["Axis Seeker", "Upper Body Rebel", "Spine Angle Challenger"],
        },
        early_extension: {  // 旧: hip_sway
            ja: ["アーリーエクステンション予備軍", "腰の伸び上がり系", "下半身暴れ屋"],
            en: ["Early Extension Candidate", "Hip Thrust Warrior", "Lower Body Rebel"],
        },
        head_movement: {    // 旧: head_level
            ja: ["ヘッドアップ予備軍", "目線の旅人", "高さ調整中"],
            en: ["Head Up Candidate", "Eye Level Traveler", "Height Adjuster"],
        },
        hand_position: {    // 旧: hand_lift
            ja: ["ハンドリフター", "手元浮き屋", "グリップ探求者"],
            en: ["Hand Lifter", "Grip Floater", "Grip Seeker"],
        },
        tempo: {
            ja: ["打ち急ぎ屋", "せっかちゴルファー", "リズム探求中"],
            en: ["Quick Swinger", "Impatient Golfer", "Rhythm Seeker"],
        },
    };

    const list = words[key][locale] || words[key]["ja"];
    return list[variant % list.length];
}

/**
 * 遊び語を取得
 */
function getPlayWord(locale: string, variant: number): string {
    const words: Record<string, string[]> = {
        ja: ["戦士", "旅人", "挑戦者", "研究家", "候補生", "予備軍"],
        en: ["Warrior", "Traveler", "Challenger", "Researcher", "Candidate", "Recruit"],
    };

    const list = words[locale] || words["ja"];
    return list[variant % list.length];
}

/**
 * EXCELLENT専用バッジプール
 */
function getExcellentBadge(locale: string, variant: number): string {
    const badges: Record<string, string[]> = {
        ja: [
            "安定感の持ち主",
            "型を持つゴルファー",
            "再現性マスター",
            "今日の完成形",
            "本日のベストスイング",
        ],
        en: [
            "Master of Consistency",
            "Golfer with Style",
            "Repeatability Master",
            "Today's Perfection",
            "Today's Best Swing",
        ],
    };

    const list = badges[locale] || badges["ja"];
    return list[variant % list.length];
}

/**
 * ALMOST_THERE専用バッジプール
 */
function getAlmostThereBadge(locale: string, variant: number): string {
    const badges: Record<string, string[]> = {
        ja: [
            "覚醒前夜ゴルファー",
            "仕上がり寸前の挑戦者",
            "あと一手の完成形",
            "ブレークスルー待ち",
            "あと一歩のゴルファー",
        ],
        en: [
            "On the Verge of Breakthrough",
            "Almost Complete Challenger",
            "One Step Away",
            "Waiting for Breakthrough",
            "Almost There Golfer",
        ],
    };

    const list = badges[locale] || badges["ja"];
    return list[variant % list.length];
}

/**
 * バッジ生成メイン関数
 */
export function generateBadge(
    score: number,
    topIssueKey: MetricKey | null,
    metaMode: MetaMode,
    locale: string,
    variant: number = 0
): string {
    // 特別モード用バッジ
    if (metaMode === "EXCELLENT") {
        return getExcellentBadge(locale, variant);
    }
    if (metaMode === "ALMOST_THERE") {
        return getAlmostThereBadge(locale, variant);
    }

    // 通常/REBUILDモード
    if (!topIssueKey) {
        // フォールバック
        return locale === "ja" ? "成長途中のゴルファー" : "Growing Golfer";
    }

    const weaknessWord = getWeaknessWord(topIssueKey, locale, variant);
    const phaseWord = getScorePhase(score, locale);
    const playWord = getPlayWord(locale, variant);

    // 日本語: "スライサー成長途中の戦士"
    // 英語: "Slicer - Growing Warrior"
    if (locale === "ja") {
        return `${weaknessWord}${phaseWord}の${playWord}`;
    } else {
        return `${weaknessWord} - ${phaseWord} ${playWord}`;
    }
}
