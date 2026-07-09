/**
 * GolfScan AI - Habit (癖) Expression Templates
 * Premium + REGULAR ユーザー専用の癖表現
 * 
 * 解禁条件（厳守）:
 * 1. Premium ユーザーのみ
 * 2. report_context = REGULAR 以上
 * 3. 同一項目で3回以上連続して低スコア
 */

export type HabitExpressionLocale = "ja" | "en";

interface HabitExpressionSet {
    /**
     * 癖の存在を示唆する表現
     * - 診断ではなく観察
     * - 言い切らない
     */
    patterns: string[];

    /**
     * 特定項目への癖表現
     */
    itemSpecific: Record<string, string[]>;
}

/**
 * 癖表現テンプレート
 */
export const HABIT_EXPRESSIONS: Record<HabitExpressionLocale, HabitExpressionSet> = {
    ja: {
        patterns: [
            "今回だけじゃなく、少し前から顔を出しやすいところかも",
            "他は入れ替わるのに、ここだけ残りやすいね",
            "無意識に戻りやすい「いつもの場所」",
            "練習中に出やすいポイントかもしれない",
            "ここ、数回続けて気になってる",
            "体が覚えてしまってる動きかも"
        ],
        itemSpecific: {
            spine_angle: [
                "起き上がりは、気づくと戻りやすいポイントみたい",
                "前傾キープ、ちょっと癖になりかけてる感じがある"
            ],
            tempo: [
                "切り返しの急ぎ、体が覚えてしまってるのかも",
                "リズムの崩れ、定着しかけてる気がする"
            ],
            swing_path: [
                "軌道の傾向、ちょっと根付いてきてるかも",
                "外からの入り、無意識に出やすいところみたい"
            ],
            head_movement: [
                "頭の動き、体に染み付いてきてるかも",
                "目線のブレ、繰り返し出てきてるポイント"
            ],
            hand_position: [
                "手元の浮き、気づくと出てきやすいかも",
                "インパクトの形、ちょっと癖になりかけてる"
            ],
            early_extension: [
                "腰の伸び上がり、無意識に出やすいところ",
                "下半身の動き、定着しかけてる感じがする"
            ]
        }
    },
    en: {
        patterns: [
            "This might be a pattern that tends to show up",
            "Unlike other areas, this one seems to stick around",
            "This could be your 'default' movement",
            "This pattern keeps appearing in practice",
            "I've noticed this for a few sessions now",
            "Your body might have memorized this movement"
        ],
        itemSpecific: {
            spine_angle: [
                "The early extension tends to creep back in",
                "Spine angle maintenance might be becoming a pattern"
            ],
            tempo: [
                "The rushed transition seems ingrained",
                "The rhythm issue appears to be settling in"
            ],
            swing_path: [
                "The path tendency might be taking root",
                "The outside approach seems to be your default"
            ],
            head_movement: [
                "Head movement might be becoming second nature",
                "Eye line instability keeps showing up"
            ],
            hand_position: [
                "Hand position at impact might be a recurring theme",
                "The floating hands pattern keeps appearing"
            ],
            early_extension: [
                "Hip thrust seems to be your body's default",
                "Lower body movement might be settling into a pattern"
            ]
        }
    }
};

/**
 * 癖表現を選択
 * @param locale 言語
 * @param metricKey 項目キー（オプション、特定項目用）
 */
export function selectHabitExpression(
    locale: HabitExpressionLocale,
    metricKey?: string
): string {
    const expressions = HABIT_EXPRESSIONS[locale];

    // 項目固有の表現がある場合は優先
    if (metricKey && expressions.itemSpecific[metricKey]) {
        const itemExpressions = expressions.itemSpecific[metricKey];
        return itemExpressions[Math.floor(Math.random() * itemExpressions.length)];
    }

    // 汎用パターンから選択
    return expressions.patterns[Math.floor(Math.random() * expressions.patterns.length)];
}

/**
 * 癖表現が解禁されているかチェック
 * 
 * 条件:
 * 1. Premium ユーザー
 * 2. report_context = REGULAR
 * 3. 同一項目で3回以上連続して低スコア
 */
export interface HabitCheckParams {
    isPremium: boolean;
    reportContext: string;
    consecutiveLowScoreCount: number;
}

export function isHabitExpressionAllowed(params: HabitCheckParams): boolean {
    return (
        params.isPremium &&
        params.reportContext === "REGULAR" &&
        params.consecutiveLowScoreCount >= 3
    );
}
