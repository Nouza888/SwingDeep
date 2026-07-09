/**
 * GolfScan AI - Judgment Titles Pool (v2: with Direction)
 * 各詳細項目の一言判定タイトル
 *
 * 構造: metric × severity × direction × 10語 = 360語
 *
 * direction は数値閾値から決定論で算出し、LLMには判断させない。
 * これにより「速すぎるのに遅すぎると書かれる」等の信頼性崩壊事故を防ぐ。
 */

// ============================================
// Direction 定義
// ============================================

export type SpineAngleDirection = "EARLY_RISE" | "OVER_HOLD";  // 起き上がり / 固めすぎ
export type TempoDirection = "FAST" | "SLOW";                   // 速すぎ / 遅すぎ
export type SwingPathDirection = "OUT_IN" | "IN_OUT";           // アウトサイドイン / インサイドアウト
export type HeadMovementDirection = "UP" | "DOWN";              // 伸び上がり / 沈み込み
export type HandPositionDirection = "LIFT" | "PRESS";           // 浮き / 詰まり
export type EarlyExtensionDirection = "EARLY" | "STUCK";        // 早伸び / 止まり

export type Direction =
    | SpineAngleDirection
    | TempoDirection
    | SwingPathDirection
    | HeadMovementDirection
    | HandPositionDirection
    | EarlyExtensionDirection;

export type MetricKey =
    | "spine_angle"
    | "tempo"
    | "swing_path"
    | "head_movement"
    | "hand_position"
    | "early_extension";

export type Severity = "good" | "ok" | "bad";

// ============================================
// Direction 閾値判定関数
// ============================================

/**
 * 各項目のdirectionを数値から決定
 * @returns [direction_A, direction_B] のタプル（A/Bの判定）
 */
export function calculateDirection(
    key: MetricKey,
    value: number
): Direction {
    switch (key) {
        case "tempo":
            // ratio < 2.2 → FAST, ratio > 3.6 → SLOW
            if (value < 2.5) return "FAST";
            if (value > 3.3) return "SLOW";
            return "FAST"; // デフォルト

        case "swing_path":
            // 正の値 = アウトサイドイン、負の値 = インサイドアウト
            return value > 0 ? "OUT_IN" : "IN_OUT";

        case "spine_angle":
            // 正の値 = 起き上がり、負の値 = 固めすぎ
            return value > 0 ? "EARLY_RISE" : "OVER_HOLD";

        case "head_movement":
            // 正の値 = 伸び上がり、負の値 = 沈み込み
            return value > 0 ? "UP" : "DOWN";

        case "hand_position":
            // 正の値 = 浮き、負の値 = 詰まり
            return value > 0 ? "LIFT" : "PRESS";

        case "early_extension":
            // 正の値 = 早伸び、負の値 = 止まり
            return value > 0 ? "EARLY" : "STUCK";

        default:
            return "FAST";
    }
}

// ============================================
// 判定タイトルプール（日本語）
// ============================================

interface DirectionTitles {
    direction_A: string[];  // EARLY_RISE, FAST, OUT_IN, UP, LIFT, EARLY
    direction_B: string[];  // OVER_HOLD, SLOW, IN_OUT, DOWN, PRESS, STUCK
}

interface SeverityTitles {
    bad: DirectionTitles;
    ok: DirectionTitles;
    good: DirectionTitles;
}

type JudgmentTitlePool = Record<MetricKey, SeverityTitles>;

export const JUDGMENT_TITLES_JA: JudgmentTitlePool = {
    // ① 前傾キープ（Spine Angle）
    spine_angle: {
        bad: {
            direction_A: [ // 起き上がり
                "我慢できず起き上がる",
                "前傾が途中で消える",
                "上体が先に逃げる",
                "インパクト前に起きる",
                "体が当てにいく",
                "前傾崩壊",
                "上体主導が強すぎ",
                "起き癖が出ている",
                "体が耐えられない",
                "姿勢が最後まで持たない"
            ],
            direction_B: [ // 固めすぎ
                "前傾を固めすぎ",
                "動けない姿勢",
                "上体がロック",
                "回転を邪魔している",
                "固定しすぎの前傾",
                "窮屈な構え",
                "体が解放されない",
                "ぎこちない前傾",
                "動作に余裕なし",
                "力が逃げない前傾"
            ]
        },
        ok: {
            direction_A: [
                "後半で起きやすい",
                "前傾が少し浅くなる",
                "粘りきれない",
                "たまに起きる",
                "日によって差が出る",
                "インパクト前が甘い",
                "姿勢が揺れる",
                "上体が先走る",
                "我慢が足りない",
                "前傾が惜しい"
            ],
            direction_B: [
                "少し固い前傾",
                "動きが出にくい",
                "回転が詰まり気味",
                "窮屈な姿勢",
                "余裕が少ない",
                "固さが残る",
                "解放が遅れる",
                "体が硬い",
                "伸びが出ない",
                "可動域が狭い"
            ]
        },
        good: {
            direction_A: [
                "前傾が最後まで残る",
                "姿勢が安定",
                "下半身主導",
                "体が自然に回る",
                "起き癖が出ていない",
                "我慢が効いている",
                "前傾キープ良好",
                "安心できる姿勢",
                "崩れにくい",
                "再現性のある前傾"
            ],
            direction_B: [
                "しなやかな前傾",
                "余裕のある姿勢",
                "固まりすぎない",
                "回転を邪魔しない",
                "自然な前傾",
                "動ける姿勢",
                "解放がスムーズ",
                "窮屈さなし",
                "バランス良好",
                "体が使えている"
            ]
        }
    },

    // ② 切り返しリズム（Tempo）
    tempo: {
        bad: {
            direction_A: [ // FAST
                "切り返しが速すぎる",
                "待てずに突っ込む",
                "打ち急ぎ",
                "力みテンポ",
                "反応で振っている",
                "ダウンが急",
                "間が作れない",
                "焦りが出ている",
                "一気に振り下ろす",
                "テンポが暴走"
            ],
            direction_B: [ // SLOW
                "間が空きすぎ",
                "待ちすぎて緩む",
                "切り返しが鈍い",
                "リズムが間延び",
                "力が伝わらない",
                "テンポが重い",
                "タメすぎ",
                "動きが遅れる",
                "一拍多い",
                "乗り遅れ"
            ]
        },
        ok: {
            direction_A: [
                "やや打ち急ぎ",
                "速さが目立つ",
                "テンポが前のめり",
                "急ぐ日がある",
                "少し早い",
                "力みが出る",
                "間が浅い",
                "速い回がある",
                "テンポにムラ",
                "落ち着き不足"
            ],
            direction_B: [
                "やや待ちすぎ",
                "間が長い日がある",
                "重めのテンポ",
                "遅れる瞬間がある",
                "タメが深い",
                "リズムに波",
                "一瞬止まる",
                "乗り遅れ気味",
                "流れが切れる",
                "間が惜しい"
            ]
        },
        good: {
            direction_A: [
                "自然な切り返し",
                "反応がスムーズ",
                "力が伝わる",
                "間がちょうどいい",
                "リズム良好",
                "流れがある",
                "再現性高い",
                "テンポ安定",
                "無理がない",
                "気持ちいい間"
            ],
            direction_B: [
                "落ち着いたリズム",
                "タメが活きている",
                "ゆったり安定",
                "間が効いている",
                "余裕のあるテンポ",
                "焦りがない",
                "コントロール良好",
                "再現性あり",
                "バランスがいい",
                "安心できる流れ"
            ]
        }
    },

    // ③ スイング軌道（Swing Path）
    swing_path: {
        bad: {
            direction_A: [ // OUT_IN
                "完全アウトサイドイン",
                "典型的カット軌道",
                "外から叩いている",
                "スライス一直線",
                "当てにいく軌道",
                "被せ打ち",
                "外回り過多",
                "押し出しカット",
                "操作感が強い",
                "逃げる軌道"
            ],
            direction_B: [ // IN_OUT
                "振り遅れフック",
                "インから出すぎ",
                "巻き込み軌道",
                "フック一直線",
                "返しすぎ",
                "内に潜りすぎ",
                "被りフック",
                "出球が左",
                "操作しすぎ",
                "捕まり過多"
            ]
        },
        ok: {
            direction_A: [
                "やや外から入り気味",
                "カット傾向",
                "フェード寄り",
                "外が少し強い",
                "日によって外",
                "方向が安定しない",
                "微妙に被る",
                "当て感が出る",
                "操作が残る",
                "軌道が惜しい"
            ],
            direction_B: [
                "インがやや強い",
                "捕まりすぎる日がある",
                "巻き込み気味",
                "フックが出る",
                "内から出やすい",
                "返りが強い",
                "操作感あり",
                "出球が安定しない",
                "捕まりムラ",
                "軌道が惜しい"
            ]
        },
        good: {
            direction_A: [
                "直進性の高い軌道",
                "素直なライン",
                "フェード安定",
                "方向が読みやすい",
                "操作感が少ない",
                "再現性あり",
                "安心できる軌道",
                "コントロール良好",
                "無理がない",
                "きれいな出球"
            ],
            direction_B: [
                "捕まりの良い軌道",
                "力が伝わるライン",
                "ストレート系",
                "強い出球",
                "安定した捕まり",
                "操作しない軌道",
                "再現性が高い",
                "素直な動き",
                "方向が安定",
                "安心感あり"
            ]
        }
    },

    // ④ 頭の安定感（Head Movement）
    head_movement: {
        bad: {
            direction_A: [ // UP
                "頭が我慢できない",
                "インパクトで浮く",
                "伸び上がり過多",
                "当てにいく動き",
                "頭が先に逃げる",
                "上体が浮きすぎ",
                "見上げて当てる",
                "最後に起きる",
                "体が突き上がる",
                "頭が残らない"
            ],
            direction_B: [ // DOWN
                "頭が落ちすぎ",
                "沈み込み過多",
                "体が沈み込む",
                "インパクトが低い",
                "下に突っ込む",
                "頭が下がりすぎ",
                "前につぶれる",
                "姿勢が低すぎ",
                "バランス崩壊",
                "沈み癖が強い"
            ]
        },
        ok: {
            direction_A: [
                "たまに浮く",
                "後半で頭が上がる",
                "伸びる日がある",
                "我慢が甘い",
                "安定しきらない",
                "浮きが出る",
                "上体が先走る",
                "頭の位置が揺れる",
                "最後が惜しい",
                "残りきらない"
            ],
            direction_B: [
                "やや沈み込み",
                "下に入りやすい",
                "姿勢が低め",
                "沈む回がある",
                "体が落ちる",
                "低さが目立つ",
                "安定感が惜しい",
                "上下動にムラ",
                "潰れ気味",
                "バランスが惜しい"
            ]
        },
        good: {
            direction_A: [
                "頭が最後まで残る",
                "安定した目線",
                "我慢が効いている",
                "上体がブレない",
                "落ち着いた動き",
                "再現性が高い",
                "安心できる位置",
                "体が突き上がらない",
                "安定感あり",
                "きれいなインパクト"
            ],
            direction_B: [
                "適度な沈み",
                "低さが活きている",
                "地面反力が使えている",
                "バランス良好",
                "無理のない低さ",
                "体が安定",
                "再現性あり",
                "コントロール良好",
                "軸が保てている",
                "安心感のある姿勢"
            ]
        }
    },

    // ⑤ インパクト時の手元（Hand Position）
    hand_position: {
        bad: {
            direction_A: [ // LIFT
                "手元が浮く",
                "インパクトで跳ねる",
                "当たりが薄い",
                "すくい打ち",
                "手が先に上がる",
                "フェースが合わない",
                "トップが多い",
                "手元が安定しない",
                "浮き癖が強い",
                "すくい感MAX"
            ],
            direction_B: [ // PRESS
                "手元が詰まる",
                "懐が消える",
                "窮屈なインパクト",
                "振り遅れ気味",
                "体に近すぎ",
                "手が逃げない",
                "フェース管理不能",
                "引っかけ量産",
                "逃げ場がない",
                "手元が苦しい"
            ]
        },
        ok: {
            direction_A: [
                "たまに浮く",
                "浮きが残る",
                "薄当たりが出る",
                "安定しきらない",
                "日によって差",
                "手元が揺れる",
                "フェースが合わない日",
                "すくいが出る",
                "インパクトが惜しい",
                "収まりが悪い"
            ],
            direction_B: [
                "やや詰まり気味",
                "窮屈な回がある",
                "懐が狭い",
                "手元に余裕がない",
                "体に近づく",
                "引っかけが出る",
                "操作感が残る",
                "インパクトが惜しい",
                "手元が忙しい",
                "余白が足りない"
            ]
        },
        good: {
            direction_A: [
                "手元が安定",
                "低く出せている",
                "フェースが合う",
                "当たりが厚い",
                "再現性が高い",
                "すくい感なし",
                "安心できる位置",
                "きれいなヒット",
                "操作しない",
                "収まりが良い"
            ],
            direction_B: [
                "懐が保てている",
                "手元に余裕あり",
                "体と距離が良い",
                "自然な位置",
                "窮屈さなし",
                "再現性が高い",
                "操作感が少ない",
                "安心感のある当たり",
                "フェース管理良好",
                "バランスがいい"
            ]
        }
    },

    // ⑥ 腰の伸び上がり（Early Extension）
    early_extension: {
        bad: {
            direction_A: [ // EARLY
                "腰が耐えきれない",
                "早く伸び上がる",
                "下半身が逃げる",
                "我慢できない腰",
                "当てにいく動き",
                "前が詰まる",
                "体が立つ",
                "腰が先に起きる",
                "パワーが逃げる",
                "伸び癖が強い"
            ],
            direction_B: [ // STUCK
                "腰が止まる",
                "回転不足",
                "タメが作れない",
                "下半身が働かない",
                "腰が固まる",
                "回らず当てる",
                "動きが途中で止まる",
                "パワーが出ない",
                "下が使えていない",
                "回転が消える"
            ]
        },
        ok: {
            direction_A: [
                "伸びが早い日がある",
                "我慢が惜しい",
                "後半で立つ",
                "腰が逃げやすい",
                "日によって差",
                "前が詰まる回",
                "安定しきらない",
                "下が耐えきれない",
                "伸びが残る",
                "惜しい腰使い"
            ],
            direction_B: [
                "回転が浅い",
                "腰が止まり気味",
                "タメが足りない",
                "下半身が惜しい",
                "回りきらない",
                "動きが途中まで",
                "パワーが出にくい",
                "腰が重い",
                "回転にムラ",
                "惜しい動き"
            ]
        },
        good: {
            direction_A: [
                "腰が粘れている",
                "下半身が耐える",
                "回転が続く",
                "パワーが逃げない",
                "安定した下",
                "再現性あり",
                "体が突っ込まない",
                "安心できる腰",
                "強さが出る",
                "余裕のある動き"
            ],
            direction_B: [
                "腰がしっかり回る",
                "タメが作れている",
                "下半身主導",
                "回転力が出る",
                "パワーが伝わる",
                "安定感あり",
                "再現性が高い",
                "動きが途切れない",
                "安心感のある回転",
                "きれいなフィニッシュ"
            ]
        }
    }
};

// ============================================
// 英語版（簡易版 - 後で拡張可能）
// ============================================

export const JUDGMENT_TITLES_EN: JudgmentTitlePool = {
    spine_angle: {
        bad: {
            direction_A: ["Early spine lift", "Losing posture", "Standing up at impact", "Can't hold spine angle", "Upper body escaping", "Posture collapse", "Rising too early", "Spine gives up", "No patience", "Position breaks"],
            direction_B: ["Spine too locked", "Over-holding posture", "Stiff setup", "Blocking rotation", "Too rigid", "Cramped address", "No release", "Restricted movement", "Tight posture", "Stuck spine"]
        },
        ok: {
            direction_A: ["Slight lift tendency", "Spine wavers late", "Can't fully hold", "Occasional rise", "Varies day to day", "Impact feels off", "Position unstable", "Upper leads", "Patience lacking", "Almost there"],
            direction_B: ["Slightly stiff", "Movement restricted", "Rotation tight", "Cramped feel", "Lacks ease", "Stiffness remains", "Late release", "Body rigid", "Limited range", "Nearly there"]
        },
        good: {
            direction_A: ["Spine holds to finish", "Stable posture", "Lower body leads", "Natural rotation", "No rising tendency", "Patient hold", "Great maintenance", "Reliable position", "Consistent", "Repeatable posture"],
            direction_B: ["Flexible posture", "Relaxed position", "Not over-locked", "Rotation-friendly", "Natural angle", "Mobile stance", "Clean release", "No tension", "Well balanced", "Body flows"]
        }
    },
    tempo: {
        bad: {
            direction_A: ["Transition too fast", "Rushing down", "Over-eager tempo", "Tension-driven", "Reactive swing", "Abrupt downswing", "No pause", "Anxious tempo", "All at once", "Runaway rhythm"],
            direction_B: ["Pause too long", "Over-waiting", "Sluggish transition", "Extended rhythm", "Power lost", "Heavy tempo", "Too much pause", "Late movement", "Extra beat", "Behind the beat"]
        },
        ok: {
            direction_A: ["Slightly rushed", "Noticeable speed", "Tempo leans forward", "Fast days", "A bit quick", "Some tension", "Shallow pause", "Speed varies", "Rhythm wavers", "Needs calm"],
            direction_B: ["Slightly delayed", "Long pause days", "Heavier tempo", "Occasional lag", "Deep pause", "Rhythm waves", "Brief stop", "Falls behind", "Flow breaks", "Pause borderline"]
        },
        good: {
            direction_A: ["Natural transition", "Smooth response", "Power transfers", "Perfect pause", "Great rhythm", "Good flow", "Highly repeatable", "Stable tempo", "Effortless", "Comfortable timing"],
            direction_B: ["Calm rhythm", "Pause works well", "Steady pace", "Effective pause", "Relaxed tempo", "No rush", "Good control", "Repeatable", "Well balanced", "Comfortable flow"]
        }
    },
    swing_path: {
        bad: {
            direction_A: ["Complete outside-in", "Classic slice path", "Hitting from outside", "Straight slice", "Reaching path", "Over-the-top", "Too much out-in", "Push-cut path", "Over-manipulated", "Escaping path"],
            direction_B: ["Hook from inside", "Excessive in-out", "Wrap-around path", "Straight hook", "Over-returning", "Too far inside", "Covered hook", "Left start", "Over-worked", "Too much draw"]
        },
        ok: {
            direction_A: ["Slight outside approach", "Cut tendency", "Fade-biased", "Outside a bit strong", "Outside some days", "Direction unstable", "Slight cover", "Contact feel", "Some manipulation", "Path borderline"],
            direction_B: ["Inside a bit strong", "Over-draw days", "Wrap tendency", "Hook appears", "Easy inside", "Strong return", "Some manipulation", "Start unstable", "Draw varies", "Path borderline"]
        },
        good: {
            direction_A: ["Straight path", "Clean line", "Stable fade", "Predictable", "Little manipulation", "Repeatable path", "Reliable path", "Good control", "Natural", "Clean start"],
            direction_B: ["Good draw path", "Power-transfer line", "Straight-draw", "Strong start", "Stable draw", "Unmanipulated", "Highly repeatable", "Natural move", "Stable direction", "Confident path"]
        }
    },
    head_movement: {
        bad: {
            direction_A: ["Head won't stay", "Lifts at impact", "Excessive rise", "Reaching for ball", "Head escapes first", "Upper floats up", "Looking up to hit", "Late rise", "Body thrusts up", "Head doesn't stay"],
            direction_B: ["Head drops too much", "Excessive dip", "Body sinking", "Impact too low", "Diving down", "Head too low", "Crushing forward", "Too low posture", "Balance gone", "Strong dip habit"]
        },
        ok: {
            direction_A: ["Occasional float", "Late head rise", "Rising days", "Patience soft", "Not fully stable", "Float appears", "Upper moves first", "Position wobbles", "Late is close", "Can't fully hold"],
            direction_B: ["Slight dip", "Easy to drop", "Low posture", "Dipping rounds", "Body drops", "Low stands out", "Stability close", "Vertical varies", "Crushing feel", "Balance close"]
        },
        good: {
            direction_A: ["Head stays to end", "Stable eye line", "Patient hold", "Upper doesn't move", "Calm movement", "Highly repeatable", "Reliable position", "No thrust up", "Stable feel", "Clean impact"],
            direction_B: ["Good depth", "Low position works", "Ground force used", "Good balance", "Natural low", "Stable body", "Repeatable", "Good control", "Axis maintained", "Confident posture"]
        }
    },
    hand_position: {
        bad: {
            direction_A: ["Hands float", "Bounce at impact", "Thin contact", "Scooping", "Hands rise first", "Face doesn't match", "Many tops", "Hands unstable", "Float habit strong", "Maximum scoop"],
            direction_B: ["Hands jammed", "Space disappears", "Cramped impact", "Behind the ball", "Too close to body", "Hands won't escape", "Face uncontrollable", "Pulling left", "No escape", "Hands suffering"]
        },
        ok: {
            direction_A: ["Occasional float", "Float remains", "Thin contact days", "Not fully stable", "Day-to-day variance", "Hands waver", "Face off days", "Scoop appears", "Impact borderline", "Settling issues"],
            direction_B: ["Slightly jammed", "Cramped rounds", "Space narrow", "Less hand room", "Getting close", "Pull appears", "Manipulation feel", "Impact borderline", "Hands busy", "Margin lacking"]
        },
        good: {
            direction_A: ["Hands stable", "Low delivery", "Face matches", "Solid contact", "Highly repeatable", "No scoop", "Reliable position", "Clean hit", "No manipulation", "Good settling"],
            direction_B: ["Space maintained", "Hand room exists", "Good body distance", "Natural position", "No cramping", "Highly repeatable", "Little manipulation", "Confident contact", "Good face control", "Well balanced"]
        }
    },
    early_extension: {
        bad: {
            direction_A: ["Hips won't hold", "Early thrust up", "Lower escapes", "Impatient hips", "Reaching to hit", "Front jams", "Body stands", "Hips rise first", "Power escapes", "Strong thrust habit"],
            direction_B: ["Hips stop", "Rotation lacking", "Can't create lag", "Lower doesn't work", "Hips freeze", "Hit without turn", "Movement stops mid", "No power", "Lower unused", "Rotation dies"]
        },
        ok: {
            direction_A: ["Early thrust days", "Patience borderline", "Late stand up", "Hips escape easy", "Varies by day", "Front jams at times", "Not fully stable", "Lower can't hold", "Thrust remains", "Hip work borderline"],
            direction_B: ["Rotation shallow", "Hips stop-ish", "Lag lacking", "Lower borderline", "Can't fully turn", "Movement partial", "Power hard", "Hips heavy", "Rotation varies", "Movement borderline"]
        },
        good: {
            direction_A: ["Hips hold well", "Lower stays", "Rotation continues", "Power doesn't escape", "Stable lower", "Repeatable", "Body doesn't dive", "Reliable hips", "Strength appears", "Comfortable movement"],
            direction_B: ["Hips turn fully", "Lag created", "Lower body leads", "Rotation power", "Power transfers", "Stable feel", "Highly repeatable", "Movement continuous", "Confident rotation", "Clean finish"]
        }
    }
};

// ============================================
// Tone 定義 & report_context による解禁制御
// ============================================

export type Tone = "SOFT" | "NORMAL" | "HARD";
export type ReportContext = "FIRST_TIME" | "GETTING_USED" | "REGULAR" | "COMEBACK";

/**
 * report_context に応じて許可される tone を返す
 * HARD は REGULAR 以外では絶対に使わない
 */
export function getAllowedTones(reportContext: ReportContext): Tone[] {
    switch (reportContext) {
        case "FIRST_TIME":
            return ["SOFT"];
        case "GETTING_USED":
            return ["SOFT", "NORMAL"];
        case "REGULAR":
            return ["NORMAL", "HARD"];
        case "COMEBACK":
            return ["SOFT", "NORMAL"];
        default:
            return ["SOFT", "NORMAL"];
    }
}

/**
 * 10語の配列を3つの tone に分類
 * Index 0-2: SOFT（観察・共感・初対面向け）
 * Index 3-6: NORMAL（標準・淡々・一般的）
 * Index 7-9: HARD（踏み込む・本音・強め）
 */
function getTitlesByTone(titles: string[], allowedTones: Tone[]): string[] {
    const soft = titles.slice(0, 3);    // 0,1,2
    const normal = titles.slice(3, 7);  // 3,4,5,6
    const hard = titles.slice(7, 10);   // 7,8,9

    const result: string[] = [];
    if (allowedTones.includes("SOFT")) result.push(...soft);
    if (allowedTones.includes("NORMAL")) result.push(...normal);
    if (allowedTones.includes("HARD")) result.push(...hard);

    // フォールバック: 結果が空なら全て返す
    return result.length > 0 ? result : titles;
}

// ============================================
// 選択関数（tone対応版）
// ============================================

/**
 * 判定タイトルを選択
 * @param key メトリクスキー
 * @param severity 重要度
 * @param direction 方向（数値から算出済み）
 * @param reportContext レポートコンテキスト
 * @param locale 言語
 */
export function selectJudgmentTitle(
    key: MetricKey,
    severity: Severity,
    direction: Direction,
    reportContext: ReportContext,
    locale: "ja" | "en"
): string {
    return selectJudgmentTitleWithTone(key, severity, direction, reportContext, locale).title;
}

/**
 * 判定タイトルとtoneを選択（本文・ドリル伝播用）
 * @returns { title, tone }
 */
export function selectJudgmentTitleWithTone(
    key: MetricKey,
    severity: Severity,
    direction: Direction,
    reportContext: ReportContext,
    locale: "ja" | "en"
): { title: string; tone: Tone } {
    const pool = locale === "ja" ? JUDGMENT_TITLES_JA : JUDGMENT_TITLES_EN;

    // keyがpoolに存在しない場合のフォールバック
    if (!pool[key]) {
        console.warn(`[selectJudgmentTitleWithTone] Unknown key: ${key}`);
        return { title: "要チェック", tone: "NORMAL" };
    }

    const severityPool = pool[key][severity];
    if (!severityPool) {
        console.warn(`[selectJudgmentTitleWithTone] Unknown severity: ${severity} for key: ${key}`);
        return { title: "要チェック", tone: "NORMAL" };
    }

    // directionからA/Bを決定
    const isDirectionA = isDirectionTypeA(key, direction);
    const allTitles = isDirectionA ? severityPool.direction_A : severityPool.direction_B;

    if (!allTitles || allTitles.length === 0) {
        console.warn(`[selectJudgmentTitleWithTone] No titles for key: ${key}, severity: ${severity}, direction: ${direction}`);
        return { title: "要チェック", tone: "NORMAL" };
    }

    // report_contextに応じてallowed_tonesを決定
    const allowedTones = getAllowedTones(reportContext);

    // ランダムでtoneを選択（許可されたtone内から）
    const selectedTone = allowedTones[Math.floor(Math.random() * allowedTones.length)];

    // 選択したtoneに対応する語彙を取得
    const titlesForTone = getTitlesByTone(allTitles, [selectedTone]);

    // ランダム選択（空配列の場合はallTitlesから）
    const finalTitles = titlesForTone.length > 0 ? titlesForTone : allTitles;
    const index = Math.floor(Math.random() * finalTitles.length);
    return {
        title: finalTitles[index] || "要チェック",
        tone: selectedTone
    };
}

/**
 * directionがA側かB側かを判定
 */
function isDirectionTypeA(key: MetricKey, direction: Direction): boolean {
    switch (key) {
        case "spine_angle":
            return direction === "EARLY_RISE";
        case "tempo":
            return direction === "FAST";
        case "swing_path":
            return direction === "OUT_IN";
        case "head_movement":
            return direction === "UP";
        case "hand_position":
            return direction === "LIFT";
        case "early_extension":
            return direction === "EARLY";
        default:
            return true;
    }
}
