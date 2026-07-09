/**
 * GolfScan AI - Severity閾値定義
 * v1.0 ゴールドスタンダード（全ペルソナ共通・固定）
 */

export type Severity = "good" | "ok" | "bad";

export type MetricKey =
    | "swing_path"
    | "spine_angle"
    | "early_extension"  // 旧: hip_sway → iOS側と統一
    | "head_movement"    // 旧: head_level → iOS側と統一
    | "hand_position"    // 旧: hand_lift → iOS側と統一
    | "tempo";

export interface SeverityThreshold {
    good: { min: number; max: number };
    ok: { min: number; max: number };
    // bad is outside ok range
}

/**
 * v1.0 Severity閾値テーブル
 * アマチュア（スコア100〜120）の再現性あるミス基準
 */
export const SEVERITY_THRESHOLDS: Record<MetricKey, SeverityThreshold> = {
    swing_path: {
        good: { min: -3, max: 3 },      // ±3°以内
        ok: { min: -7, max: 7 },        // ±3〜7°
        // bad: ±7°以上
    },
    spine_angle: {
        good: { min: -3, max: 3 },      // ±3°以内
        ok: { min: -6, max: 6 },        // ±3〜6°
        // bad: ±6°以上
    },
    early_extension: {  // 旧: hip_sway
        good: { min: -5, max: 5 },      // ±5%以内
        ok: { min: -10, max: 10 },      // ±5〜10%
        // bad: ±10%以上
    },
    head_movement: {    // 旧: head_level
        good: { min: -2, max: 2 },      // ±2cm以内
        ok: { min: -4, max: 4 },        // ±2〜4cm
        // bad: ±4cm以上
    },
    hand_position: {    // 旧: hand_lift
        good: { min: -2, max: 2 },      // ±2cm以内
        ok: { min: -5, max: 5 },        // ±2〜5cm
        // bad: ±5cm以上
    },
    tempo: {
        good: { min: 2.6, max: 3.2 },   // 2.6〜3.2
        ok: { min: 2.2, max: 3.6 },     // 2.2〜2.6 or 3.2〜3.6
        // bad: <2.2 or >3.6
    },
};

/**
 * 数値からseverityを判定
 */
export function calculateSeverity(key: MetricKey, value: number): Severity {
    const threshold = SEVERITY_THRESHOLDS[key];

    if (value >= threshold.good.min && value <= threshold.good.max) {
        return "good";
    }
    if (value >= threshold.ok.min && value <= threshold.ok.max) {
        return "ok";
    }
    return "bad";
}

/**
 * Meta Mode定義
 */
export type MetaMode = "EXCELLENT" | "ALMOST_THERE" | "REBUILD" | "NORMAL";

/**
 * severityリストからMeta Modeを決定
 */
export function calculateMetaMode(severities: Severity[]): MetaMode {
    const goodCount = severities.filter(s => s === "good").length;
    const badCount = severities.filter(s => s === "bad").length;

    if (goodCount === 6) {
        return "EXCELLENT";
    }
    if (goodCount === 5) {
        return "ALMOST_THERE";
    }
    if (badCount >= 4) {
        return "REBUILD";
    }
    return "NORMAL";
}

/**
 * 表示名定義（日本語/英語）
 */
export const METRIC_DISPLAY_NAMES: Record<MetricKey, Record<string, string>> = {
    swing_path: { ja: "スイング軌道", en: "Swing Path" },
    spine_angle: { ja: "前傾キープ", en: "Spine Angle" },
    early_extension: { ja: "腰の伸び上がり", en: "Hip Extension" },  // 旧: hip_sway
    head_movement: { ja: "頭の安定感", en: "Head Stability" },        // 旧: head_level
    hand_position: { ja: "インパクト時の手元", en: "Hand Position" }, // 旧: hand_lift
    tempo: { ja: "切り返しリズム", en: "Transition Timing" },
};
