/**
 * GolfScan AI - ドリルライブラリ v2.0
 * プール式ドリル選択システム
 */

import { MetricKey, Severity } from "./severityThresholds";
import * as spineAngleDrillPool from "./drillPools/spineAngleDrillPool.json";
import * as swingPathDrillPool from "./drillPools/swingPathDrillPool.json";
import * as earlyExtensionDrillPool from "./drillPools/earlyExtensionDrillPool.json";
import * as headMovementDrillPool from "./drillPools/headMovementDrillPool.json";
import * as tempoDrillPool from "./drillPools/tempoDrillPool.json";
import * as handPositionDrillPool from "./drillPools/handPositionDrillPool.json";

// =============================================================================
// Types
// =============================================================================

// Spine Angle directions
export type SpineAngleDirection = "lose_forward_bend" | "too_much_forward_bend" | "maintain";
// Swing Path directions
export type SwingPathDirection = "out_to_in" | "in_to_out" | "maintain";
// Early Extension / Hip Sway directions
export type EarlyExtensionDirection = "too_much_sway" | "too_little_sway" | "maintain";
// Head Movement directions
export type HeadMovementDirection = "too_much_rise" | "too_much_drop" | "maintain";
// Tempo directions
export type TempoDirection = "too_fast_downswing" | "too_slow_downswing" | "maintain";
// Hand Position directions
export type HandPositionDirection = "too_much_lift" | "too_little_lift" | "maintain";
// Combined drill direction type
export type DrillDirection = SpineAngleDirection | SwingPathDirection | EarlyExtensionDirection | HeadMovementDirection | TempoDirection | HandPositionDirection;
export type DrillIntensity = "light" | "medium";
export type DrillVariantType = "CHECK" | "SENSE" | "CONTROL" | "TRANSFER";

export interface LocalizedString {
    ja: string;
    en: string;
}

export interface LocalizedStringArray {
    ja: string[];
    en: string[];
}

export interface PoolDrill {
    drill_id: string;
    metric_key: string;
    direction: DrillDirection;
    intensity: DrillIntensity;
    variant_type: DrillVariantType;
    title: LocalizedString;
    intent: LocalizedString;
    steps: LocalizedStringArray;
    reps: string;
    tools: string[];
    ng: LocalizedStringArray;
    time_sec: number;
    tags: string[];
    cooldown_days: number;
}

export interface DrillPool {
    meta: {
        version: string;
        metric_key: string;
        description: string;
    };
    drills: PoolDrill[];
    maintain_drills: PoolDrill[];
}

export interface SelectedDrill {
    drill_id: string;
    title: string;
    intent: string;
    steps: string[];
    reps: string;
    tools: string[];
    ng: string[];
    variant_type: DrillVariantType;
    time_sec: number;
}

export interface DrillHistory {
    drill_id: string;
    used_at: string; // ISO date string
    variant_type: DrillVariantType;
}

// =============================================================================
// Drill Pool Registry
// =============================================================================

const DRILL_POOLS: Partial<Record<MetricKey, DrillPool>> = {
    spine_angle: spineAngleDrillPool as DrillPool,
    swing_path: swingPathDrillPool as DrillPool,
    early_extension: earlyExtensionDrillPool as DrillPool,
    head_movement: headMovementDrillPool as DrillPool,
    tempo: tempoDrillPool as DrillPool,
    hand_position: handPositionDrillPool as DrillPool,
};

// =============================================================================
// Legacy Drill Library (fallback for metrics without pools)
// =============================================================================

export interface DrillMaterial {
    title: Record<string, string>;
    baseInstruction: Record<string, string>;
}

export const DRILL_LIBRARY: Record<MetricKey, DrillMaterial> = {
    swing_path: {
        title: { ja: "タオル挟みドリル", en: "Towel Drill" },
        baseInstruction: {
            ja: "両脇にタオルを挟んだまま素振りをします。腕と体の一体感を感じながら、クラブが自然なプレーンを通る感覚を掴んでください。",
            en: "Swing with a towel tucked under both arms. Feel the connection between your arms and body as the club naturally follows the correct plane."
        }
    },
    spine_angle: {
        title: { ja: "壁キープドリル", en: "Wall Drill" },
        baseInstruction: {
            ja: "壁にお尻を軽くつけた状態でアドレスし、スイング中もお尻が離れないように意識します。体の軸を保つ感覚を養います。",
            en: "Address with your hips lightly touching a wall. Keep contact throughout the swing to maintain your spine angle."
        }
    },
    early_extension: {
        title: { ja: "お尻キープドリル", en: "Hip Stay Drill" },
        baseInstruction: {
            ja: "スイング中、お尻がボールに向かって突っ込まないように意識します。壁やクラブを背中に当てて練習すると効果的です。",
            en: "Focus on keeping your hips from thrusting toward the ball during the swing. Practice with a wall or club against your back for feedback."
        }
    },
    head_movement: {
        title: { ja: "鏡チェックドリル", en: "Mirror Check Drill" },
        baseInstruction: {
            ja: "鏡の前でゆっくり素振りをし、頭の位置が上下しないか確認します。目線を一定に保つ意識を持ってください。",
            en: "Slow swing in front of a mirror, watching your head position. Focus on keeping your eye level steady throughout."
        }
    },
    hand_position: {
        title: { ja: "グリップ固定ドリル", en: "Grip Connection Drill" },
        baseInstruction: {
            ja: "グリップエンドを体の中心に向けたまま、胸の回転でクラブを上げる練習をします。手だけで持ち上げない感覚を養います。",
            en: "Keep the grip end pointing at your body center while rotating your chest to lift the club. Avoid lifting with just your hands."
        }
    },
    tempo: {
        title: { ja: "カウントスイングドリル", en: "Count Swing Drill" },
        baseInstruction: {
            ja: "「いち」でバックスイング、「に」でトップ、「さん」でダウンからフィニッシュ。声に出しながらリズムを整えます。",
            en: "Count 'one' on backswing, 'two' at the top, 'three' through impact. Say it out loud to build consistent rhythm."
        }
    }
};

// =============================================================================
// Direction Detection
// =============================================================================

/**
 * Spine Angleのdirectionを判定
 * @param spineAngleDiff アドレス時との前傾角度差（impact - address）
 * @returns direction
 * 
 * Note: 正の値 = 起き上がり（前傾が浅くなる）= lose_forward_bend
 *       負の値 = 前傾が深くなる = too_much_forward_bend
 */
export function detectSpineAngleDirection(spineAngleDiff: number): SpineAngleDirection {
    // 閾値：±2度以内は維持と判定
    if (Math.abs(spineAngleDiff) <= 2) {
        return "maintain";
    }
    return spineAngleDiff > 0 ? "lose_forward_bend" : "too_much_forward_bend";
}

/**
 * Swing Pathのdirectionを判定
 * @param swingPathValue スイング軌道の値（負 = out_to_in、正 = in_to_out）
 * @returns direction
 * 
 * Note: 負の値 = カット軌道（out_to_in）
 *       正の値 = インサイドアウト過多（in_to_out）
 */
export function detectSwingPathDirection(swingPathValue: number): SwingPathDirection {
    // 閾値：±3以内は維持と判定
    if (Math.abs(swingPathValue) <= 3) {
        return "maintain";
    }
    return swingPathValue < 0 ? "out_to_in" : "in_to_out";
}

/**
 * Early Extension / Hip Swayのdirectionを判定
 * @param hipMoveRatio 腰の移動量（正 = 流れすぎ、負 = 動かなさすぎ）
 * @returns direction
 * 
 * Note: 正の値 = 流れすぎ（too_much_sway）
 *       負の値 = 動かなさすぎ（too_little_sway）
 */
export function detectEarlyExtensionDirection(hipMoveRatio: number): EarlyExtensionDirection {
    // 閾値：±5%以内は維持と判定
    if (Math.abs(hipMoveRatio) <= 5) {
        return "maintain";
    }
    return hipMoveRatio > 0 ? "too_much_sway" : "too_little_sway";
}

/**
 * Head Movementのdirectionを判定
 * @param headHeightDiff 頭の高さ変化（正 = 起き上がり、負 = 沈み込み）
 * @returns direction
 */
export function detectHeadMovementDirection(headHeightDiff: number): HeadMovementDirection {
    // 閾値：±3%以内は維持と判定
    if (Math.abs(headHeightDiff) <= 3) {
        return "maintain";
    }
    return headHeightDiff > 0 ? "too_much_rise" : "too_much_drop";
}

/**
 * Tempoのdirectionを判定
 * @param tempoRatio ダウン/バック比率（1より大きい = 速すぎ、1より小さい = 遅すぎ）
 * @returns direction
 * 
 * Note: tempoRatio > 1.3 = too_fast_downswing
 *       tempoRatio < 0.7 = too_slow_downswing
 */
export function detectTempoDirection(tempoRatio: number): TempoDirection {
    // 閾値：0.7〜1.3は維持と判定
    if (tempoRatio >= 0.7 && tempoRatio <= 1.3) {
        return "maintain";
    }
    return tempoRatio > 1.3 ? "too_fast_downswing" : "too_slow_downswing";
}

/**
 * Hand Positionのdirectionを判定
 * @param handLiftAmount 手の浮き量（正 = 浮きすぎ、負 = 潰れすぎ）
 * @returns direction
 */
export function detectHandPositionDirection(handLiftAmount: number): HandPositionDirection {
    // 閾値：±5%以内は維持と判定
    if (Math.abs(handLiftAmount) <= 5) {
        return "maintain";
    }
    return handLiftAmount > 0 ? "too_much_lift" : "too_little_lift";
}

// =============================================================================
// Intensity Detection
// =============================================================================

/**
 * Severityからintensityを判定
 */
export function detectIntensity(severity: Severity): DrillIntensity {
    return severity === "bad" ? "medium" : "light";
}

// =============================================================================
// Drill Selection
// =============================================================================

/**
 * ドリルを選択（プール式）
 */
export function selectDrill(
    metricKey: MetricKey,
    direction: DrillDirection,
    intensity: DrillIntensity,
    locale: string,
    drillHistory: DrillHistory[]
): SelectedDrill | null {
    const pool = DRILL_POOLS[metricKey];

    if (!pool) {
        // プールがない場合はレガシーフォールバック
        return null;
    }

    // 維持の場合は維持ドリルから選択
    const drillSource = direction === "maintain" ? pool.maintain_drills : pool.drills;

    // 1. 条件に合うドリルを抽出
    let candidates = drillSource.filter(d =>
        d.direction === direction && d.intensity === intensity
    );

    if (candidates.length === 0) {
        // intensityを緩和して再検索
        candidates = drillSource.filter(d => d.direction === direction);
    }

    if (candidates.length === 0) {
        return null;
    }

    // 2. cooldown期間内のドリルを除外
    const now = new Date();
    const availableDrills = candidates.filter(drill => {
        const historyEntry = drillHistory.find(h => h.drill_id === drill.drill_id);
        if (!historyEntry) return true;

        const usedAt = new Date(historyEntry.used_at);
        const daysSinceUsed = (now.getTime() - usedAt.getTime()) / (1000 * 60 * 60 * 24);
        return daysSinceUsed >= drill.cooldown_days;
    });

    // 3. 直近のvariant_typeと被らないものを優先
    const recentHistory = drillHistory
        .filter(h => h.drill_id.startsWith(metricKey))
        .sort((a, b) => new Date(b.used_at).getTime() - new Date(a.used_at).getTime())
        .slice(0, 2);

    const recentVariantTypes = new Set(recentHistory.map(h => h.variant_type));

    let selectedDrill: PoolDrill | undefined;

    // variant_typeが被らないものを優先
    const nonOverlapping = availableDrills.filter(d => !recentVariantTypes.has(d.variant_type));

    if (nonOverlapping.length > 0) {
        // ランダム選択
        selectedDrill = nonOverlapping[Math.floor(Math.random() * nonOverlapping.length)];
    } else if (availableDrills.length > 0) {
        // 4. 残りがなければ利用可能なものからランダム選択
        selectedDrill = availableDrills[Math.floor(Math.random() * availableDrills.length)];
    } else if (candidates.length > 0) {
        // cooldown中でも候補があれば最も古いものを選択
        const withHistory = candidates.map(drill => {
            const historyEntry = drillHistory.find(h => h.drill_id === drill.drill_id);
            return {
                drill,
                usedAt: historyEntry ? new Date(historyEntry.used_at).getTime() : 0
            };
        }).sort((a, b) => a.usedAt - b.usedAt);

        selectedDrill = withHistory[0].drill;
    }

    if (!selectedDrill) {
        return null;
    }

    // ローカライズして返す
    const lang = locale === "en" ? "en" : "ja";
    return {
        drill_id: selectedDrill.drill_id,
        title: selectedDrill.title[lang] || selectedDrill.title.ja,
        intent: selectedDrill.intent[lang] || selectedDrill.intent.ja,
        steps: selectedDrill.steps[lang] || selectedDrill.steps.ja,
        reps: selectedDrill.reps,
        tools: selectedDrill.tools,
        ng: selectedDrill.ng[lang] || selectedDrill.ng.ja,
        variant_type: selectedDrill.variant_type,
        time_sec: selectedDrill.time_sec
    };
}

// =============================================================================
// Legacy getDrillMaterial (for backward compatibility)
// =============================================================================

export function getDrillMaterial(key: MetricKey, locale: string): {
    title: string;
    baseInstruction: string;
} {
    const material = DRILL_LIBRARY[key];
    return {
        title: material.title[locale] || material.title.ja,
        baseInstruction: material.baseInstruction[locale] || material.baseInstruction.ja
    };
}

