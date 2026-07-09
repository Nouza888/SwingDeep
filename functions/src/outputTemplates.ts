/**
 * GolfScan AI - 出力テンプレート定義
 * Layer2: 出力構造エンジン（metaモード別）
 */

import { MetaMode } from "./severityThresholds";

/**
 * 総評カードテンプレート（metaモード別）
 */
export const OVERALL_CARD_TEMPLATES: Record<MetaMode, string> = {
    EXCELLENT: `
出力：総評カード（SNSシェア用、4〜6行）

## このモードの特徴
- 全項目がgoodの「完成形」状態
- 評価ではなく「認定・確認」モード
- 課題を無理に捻り出さない

## 構成
1) 完成度を祝福する一言
2) 今日の安定感を具体的に言語化
3) 維持・再現できていることへの承認
4) 次のスイングへの軽い期待

## 禁止
- ドリルや詳細メカニクスの説明
- 課題探し
- 「でも〜」という留保

## トーン例
「今日は直す日じゃない。完成度を確認できた日。」
`,

    ALMOST_THERE: `
出力：総評カード（SNSシェア用、4〜6行）

## このモードの特徴
- 5項目good、1項目だけ惜しい
- 「ほぼ完成」を冒頭で断言
- 唯一の課題だけにフォーカス

## 構成
1) 「ほぼ出来上がっている」という断言
2) 5つの安定を武器として言語化
3) 唯一の惜しい点を「ブレーキ」として軽く触れる
4) 読み進めたくなるヒント

## 禁止
- ドリルや詳細メカニクスの説明
- 他のgood項目の詳細

## トーン例
「ほとんど出来上がってる。あと一箇所だけが、結果にブレーキをかけてる。」
`,

    REBUILD: `
出力：総評カード（SNSシェア用、4〜6行）

## このモードの特徴
- 課題が多い状態（bad 4件以上）
- 判定は正直に出すが、UXは「整理して進める」演出で守る
- 全部一気にではなく「順番に片付ける」

## 構成
1) 今日は「整理する日」という明示
2) 状態の客観的な要約（嘘をつかない）
3) 最優先1項目だけに意識を向ける誘導
4) 読み進めたくなる期待

## 禁止
- ドリルや詳細メカニクスの説明
- 過度な慰め
- 嘘の希望

## トーン例
「今日は片付ける日。全部は無理だから、一番大事なところから整理しよう。」
`,

    NORMAL: `
出力：総評カード（SNSシェア用、4〜6行）

## このモードの特徴
- 通常の混合状態
- 危険度順に課題を提示

## 構成
1) スコアに感情的な意味を与える
2) 明確な強み（武器）を1つ
3) 「ちょっと惜しい」ポイントを1つ（優しい言葉で）
4) 読み進めたくなるヒント（未完結感）

## 禁止
- ドリルや詳細メカニクスの説明
- 数値の説明

## トーン例
「武器はある。でも、ちょっとだけ惜しいところがある。」
`
};

/**
 * 詳細項目テンプレート（metaモード別）
 */
export const DETAIL_ITEM_TEMPLATES: Record<MetaMode, string> = {
    EXCELLENT: `
出力：1項目の詳細解説（スマホ一画面想定）

## このモードの特徴
- good項目なので「維持・確認」の文脈
- 課題発掘は禁止

## 構成
1) 安定していることへの承認
2) 何が良いのか具体的に言語化（体の感覚で）
3) この状態を維持するためのポイント
4) 次のスイングで意識すべきこと（保守的）

## 禁止
- 箇条書き
- 課題探し
- 「もっとこうすれば」
`,

    ALMOST_THERE: `
出力：1項目の詳細解説（スマホ一画面想定）

## このモードの特徴
- good項目は短く安心材料として
- 唯一のnot-good項目だけ深く扱う

## 構成（good項目の場合）
1) 「ここはOK」の一言
2) 武器として簡潔に言語化
3) 続きを読み進める誘導

## 構成（not-good項目の場合）
1) 「ここだけが惜しい」という導入
2) 何が起きているか（体の感覚で、比喩1つまで）
3) 考えられる原因（1-2仮説、優しい推測）
4) 変わらないとどうなるか（よくあるミス傾向）
5) 希望的なリフレーミング（全部作り直しではなく、順番の調整）

## 禁止
- 箇条書き
- 同じ文型の繰り返し
`,

    REBUILD: `
出力：1項目の詳細解説（スマホ一画面想定）

## このモードの特徴
- 上位1-2項目を深く、残りは短く
- 全部直す必要はないことを伝える

## 構成（上位項目の場合）
1) 「まずはここから」という導入
2) 何が起きているか（体の感覚で）
3) 考えられる原因（1仮説に絞る）
4) ここを直すと何が変わるか
5) 希望的なリフレーミング

## 構成（下位項目の場合）
1) 「これは後でいい」の明示
2) 今は意識しなくていい理由
3) 上位項目が直った後の話

## 禁止
- 箇条書き
- 全部同時に直そうとする空気
`,

    NORMAL: `
出力：1項目の詳細解説（スマホ一画面想定）

## 構成
1) 気づきにくいポイントへの導入（さりげなく）
2) 何が起きているか（体の感覚に翻訳、比喩1つまで）
3) 考えられる原因（1-2仮説、優しい推測）
4) 変わらないとどうなるか（よくあるミス傾向）
5) 希望的なリフレーミング（小さな順番の調整、全部作り直しではない）

## 禁止
- 箇条書き
- 同じ文型の繰り返し
- 会話口調を維持
`
};

/**
 * ドリルテンプレート（フォールバック用）
 */
export const DRILL_TEMPLATE = `
出力：ドリルの導入＋本文

## 構成
1) このドリルが先ほどの課題とどう繋がるか（感情的な導入）
2) やることでどんな感覚・気づきが得られるか
3) 技術的な手順（短く、マニュアル禁止）
4) 優しい励まし

## ペルソナ文体（必須）
- 選択されたペルソナの語尾・絵文字を必ず使ってください
- ドリル本文にも必ずペルソナの文体を反映してください

## 禁止
- 長い手順書
- 冷たい説明
- 数値の羅列
- ペルソナ無視の標準敬語
`;

/**
 * ペルソナ対応ドリルテンプレート生成（推奨）
 * @param drillToneHint PersonaDefinition.drillToneHintから取得
 * @param allowedEmojis PersonaDefinition.allowedEmojisから取得
 */
export function getDrillTemplate(drillToneHint: string, allowedEmojis: string[]): string {
    const emojiList = allowedEmojis.length > 0
        ? `使用可能絵文字: ${allowedEmojis.join(' ')}`
        : '絵文字は使用しない';

    return `
出力：ドリルの導入＋本文

## 構成
1) このドリルが先ほどの課題とどう繋がるか（感情的な導入）
2) やることでどんな感覚・気づきが得られるか
3) 技術的な手順（短く、マニュアル禁止）
4) 優しい励まし

## ペルソナ文体（必須）
${drillToneHint}
${emojiList}

## 禁止
- 長い手順書
- 冷たい説明
- 数値の羅列
- ペルソナ無視の標準敬語
`;
}

/**
 * JSON出力強制テンプレート
 */
export const JSON_OUTPUT_INSTRUCTION = `
## 出力形式（厳守）
- 必ず有効なJSONのみを出力してください
- JSON以外のテキスト（説明文、マークダウン）は絶対に含めないでください
- レスポンス全体がJSON.parseで解析可能であること

## 出力スキーマ
{
  "overall_card_text": "（4〜6行の総評カード）",
  "details": [
    {
      "key": "項目キー",
      "detail_text": "詳細解説テキスト",
      "detail_key_phrases": ["記憶に残したいフレーズ1", "記憶に残したいフレーズ2"],
      "drill_intro_text": "ドリル導入文",
      "drill_title": "ドリルタイトル",
      "drill_text": "ドリル本文",
      "drill_key_phrases": ["ドリルで覚えるフレーズ"]
    }
    // 6件
  ]
}

## key_phrasesルール（重要）
- detail_key_phrases: detail_text内のフレーズを1〜2個抽出。ユーザーが覚えるべき核心。
- drill_key_phrases: drill_text内のフレーズを1〜2個抽出。ドリルのポイント。
- 抽出するフレーズはdetail_text/drill_text内に完全一致で存在すること。
- 記号や絵文字は含めない。10〜25文字程度が目安。
`;


/**
 * 初回演出テンプレート（FIRST_TIME専用）
 * report_context = FIRST_TIME の時のみ使用
 */
export const FIRST_TIME_TEMPLATES = {
    /**
     * 初回挨拶（meta_mode別）
     */
    greetings: {
        ja: {
            EXCELLENT: `
【初対面の挨拶が必須】
- 必ず「はじめまして」「初めてのチェックですね」などの初対面表現を含める
- 「最初のチェックとしては、正直ちょっと驚いてる」という導入
- 完成度を祝福しつつ、これからの関係性の始まりを示す
- 「これから一緒に見ていきましょう」のような約束
`,
            ALMOST_THERE: `
【初対面の挨拶が必須】
- 必ず「はじめまして」「初めてのチェックですね」などの初対面表現を含める
- 「最初からこの完成度は素晴らしい」という導入
- 「あと一歩、一緒に詰めていきましょう」という約束
`,
            NORMAL: `
【初対面の挨拶が必須】
- 必ず「はじめまして」「初めての分析ですね」などの初対面表現を含める
- 「ここから一緒に磨いていきましょう」という関係性の始まり
- 今日の役割を明示（「まずは現状を整理しよう」）
`,
            REBUILD: `
【初対面の挨拶が必須】
- 必ず「はじめまして」「初めてのチェックですね」などの初対面表現を含める
- 「立て直すところから一緒に始めましょう」という導入
- 焦らず順番に取り組む姿勢を示す
- 暖かい励まし
`
        },
        en: {
            EXCELLENT: `
【First meeting greeting required】
- Must include phrases like "Nice to meet you" or "This is our first check"
- "I'm honestly surprised by your first analysis" introduction
- Celebrate the completion while indicating the start of our journey
- Promise like "Let's continue watching your progress together"
`,
            ALMOST_THERE: `
【First meeting greeting required】
- Must include "Nice to meet you" or "This is our first check"
- "This level of completion from the start is impressive" introduction
- "Let's work on that last step together" promise
`,
            NORMAL: `
【First meeting greeting required】
- Must include "Nice to meet you" or "This is your first analysis"
- "Let's polish your swing together from here" relationship start
- Clarify today's role ("First, let's organize where you stand")
`,
            REBUILD: `
【First meeting greeting required】
- Must include "Nice to meet you" or "This is our first check"
- "Let's start rebuilding together" introduction
- Show patience and step-by-step approach
- Warm encouragement
`
        }
    }
};

/**
 * 今日のまとめテンプレート（日本語）
 */
export const TODAY_SUMMARY_TEMPLATE = `
## 「今日のまとめ」セクションを出力に含める

### 構成
1. 今日のレポートタイプ（例：惜敗回、覚醒前夜、完成確認）
2. 今日最優先でやるべき"1テーマ"（1行で）
3. 今日やらなくていいこと（Permission to Ignore）

### 禁止
- 複数テーマの並列
- 長い説明
`;

// =============================================================================
// English Templates
// =============================================================================

/**
 * 総評カードテンプレート（英語版）
 */
export const OVERALL_CARD_TEMPLATES_EN: Record<MetaMode, string> = {
    EXCELLENT: `
Output: Overall Card (for social share, 4–6 lines)

## Mode Traits
- All items are "good" (a finished / polished state)
- This is "certify & confirm" mode, not evaluation
- Do NOT force extra issues

## Structure
1) One line celebrating the current completeness
2) Put today's stability into concrete words
3) Acknowledge what's being maintained / repeated well
4) Light expectation for the next swing

## Do NOT
- Drill suggestions or deep mechanics
- Issue hunting
- "But..." reservations

## Tone example
"Today isn't a 'fix' day — it's a 'confirm it's solid' day."
`,

    ALMOST_THERE: `
Output: Overall Card (for social share, 4–6 lines)

## Mode Traits
- 5 items are "good", only 1 is slightly off
- Open by stating: "You're basically there"
- Focus on the ONE remaining issue only

## Structure
1) A clear statement: "You're almost finished"
2) Frame the 5 stable points as your weapons
3) Mention the one weak point as a small "brake"
4) A hint that makes the reader want to continue

## Do NOT
- Drill suggestions or deep mechanics
- Detailed explanation of other "good" items

## Tone example
"You're basically there. One spot is still tapping the brakes on your results."
`,

    REBUILD: `
Output: Overall Card (for social share, 4–6 lines)

## Mode Traits
- Many issues (4+ "bad")
- Be honest in judgment, but protect UX by organizing the path forward
- Not "fix everything" — "fix in order"

## Structure
1) State: "Today is an organizing day"
2) Objective summary (no lies)
3) Direct attention to ONE top priority
4) A line that makes them want to keep reading

## Do NOT
- Drill suggestions or deep mechanics
- Excessive comfort
- Fake optimism

## Tone example
"Today is a clean-up day. We can't fix everything at once — so we start with the one that matters most."
`,

    NORMAL: `
Output: Overall Card (for social share, 4–6 lines)

## Mode Traits
- Mixed, normal state
- Present issues in order of risk / impact

## Structure
1) Give the score an emotional meaning
2) One clear strength (your weapon)
3) One "slightly off" point (in gentle words)
4) A hint that makes the reader want to continue (open loop)

## Do NOT
- Drill suggestions or deep mechanics
- Explaining numbers

## Tone example
"You've got a weapon. But there's one small thing holding you back."
`
};

/**
 * 詳細項目テンプレート（英語版）
 */
export const DETAIL_ITEM_TEMPLATES_EN: Record<MetaMode, string> = {
    EXCELLENT: `
Output: One detail explanation (fits one mobile screen)

## Mode Traits
- This item is "good" → maintenance / confirmation context
- Do NOT dig for new issues

## Structure
1) Acknowledge stability
2) Describe what's good in concrete body-feel terms
3) A key point to maintain this state
4) A conservative focus for the next swing

## Do NOT
- Bullet points
- Issue hunting
- "If you do even more..."
`,

    ALMOST_THERE: `
Output: One detail explanation (fits one mobile screen)

## Mode Traits
- Good items should be short as reassurance
- Only the ONE not-good item gets deep treatment

## Structure (for a GOOD item)
1) One line: "This is OK"
2) Frame it briefly as a weapon
3) Invite the reader to continue

## Structure (for a NOT-GOOD item)
1) "This is the one missing piece" intro
2) What's happening (body-feel terms; up to one metaphor)
3) Likely causes (1–2 gentle hypotheses)
4) If unchanged: common miss tendencies
5) Hopeful reframing (not a rebuild; just adjusting the order)

## Do NOT
- Bullet points
- Repeating the same sentence pattern
`,

    REBUILD: `
Output: One detail explanation (fits one mobile screen)

## Mode Traits
- Go deep on top 1–2 items; keep the rest short
- Tell them they don't need to fix everything now

## Structure (for TOP items)
1) "Start here first" intro
2) What's happening (body-feel terms)
3) Likely cause (one hypothesis only)
4) What changes if you fix this
5) Hopeful reframing

## Structure (for LOWER items)
1) Explicitly say: "This can wait"
2) Why it doesn't need attention now
3) Mention: revisit after top items improve

## Do NOT
- Bullet points
- Creating a "fix everything at once" vibe
`,

    NORMAL: `
Output: One detail explanation (fits one mobile screen)

## Structure
1) A subtle intro to a hard-to-notice point
2) What's happening (translate into body-feel; up to one metaphor)
3) Likely causes (1–2 gentle hypotheses)
4) If unchanged: common miss tendencies
5) Hopeful reframing (small order adjustment; not a full rebuild)

## Do NOT
- Bullet points
- Repeating the same sentence pattern
- Keep a conversational tone
`
};

/**
 * ドリルテンプレート（英語版）
 */
export const DRILL_TEMPLATE_EN = `
Output: Drill intro + main text

## Structure
1) Emotional bridge: how this drill connects to the issue above
2) What sensations / awareness this drill should produce
3) Technical steps (short; do NOT write a manual)
4) Gentle encouragement

## Persona Style (Required)
- You MUST use the selected persona's tone and emojis
- Persona style must also appear inside the drill body

## Do NOT
- Long step-by-step manuals
- Cold, detached explanations
- Listing numbers only
- Ignoring persona style and writing generic polite text
`;

/**
 * ペルソナ対応ドリルテンプレート生成（英語版）
 */
export function getDrillTemplateEN(drillToneHint: string, allowedEmojis: string[]): string {
    const emojiList = allowedEmojis.length > 0
        ? `Allowed emojis: ${allowedEmojis.join(' ')}`
        : 'Do not use emojis';

    return `
Output: Drill intro + main text

## Structure
1) Emotional bridge: how this drill connects to the issue above
2) What sensations / awareness this drill should produce
3) Technical steps (short; do NOT write a manual)
4) Gentle encouragement

## Persona Style (Required)
${drillToneHint}
${emojiList}

## Do NOT
- Long step-by-step manuals
- Cold, detached explanations
- Listing numbers only
- Ignoring persona style and writing generic polite text
`;
}

/**
 * JSON出力強制テンプレート（英語版）
 */
export const JSON_OUTPUT_INSTRUCTION_EN = `
## Output format (Strict)
- Output MUST be valid JSON only
- Do NOT include any extra text (no explanations, no markdown)
- The full response must be parseable via JSON.parse

## Output schema
{
  "overall_card_text": "(Overall card, 4–6 lines)",
  "details": [
    {
      "key": "item_key",
      "detail_text": "detail explanation text",
      "detail_key_phrases": ["core phrase 1", "core phrase 2"],
      "drill_intro_text": "drill intro text",
      "drill_title": "drill title",
      "drill_text": "drill body text",
      "drill_key_phrases": ["drill core phrase"]
    }
    // 6 items
  ]
}

## key_phrases rules (Important)
- detail_key_phrases: extract 1–2 phrases from detail_text that the user should remember.
- drill_key_phrases: extract 1–2 phrases from drill_text that capture the drill's key point.
- Extracted phrases must appear EXACTLY in the source text (detail_text/drill_text).
- Do not include symbols or emojis. Target length: ~10–25 characters (adjust naturally for English).
`;

/**
 * 今日のまとめテンプレート（英語版）
 */
export const TODAY_SUMMARY_TEMPLATE_EN = `
## Include a "Today's Summary" section in the output

### Structure
1) Today's report type (e.g., "close call", "pre-breakthrough", "confirmation day")
2) The ONE top theme to work on today (one line)
3) What you do NOT need to work on today (Permission to Ignore)

### Do NOT
- Multiple themes listed in parallel
- Long explanations
`;

// =============================================================================
// Locale-aware Getter Functions
// =============================================================================

export type Locale = "ja" | "en";

/**
 * 言語に応じて総評カードテンプレートを取得
 */
export function getOverallCardTemplate(metaMode: MetaMode, locale: Locale): string {
    return locale === "en"
        ? OVERALL_CARD_TEMPLATES_EN[metaMode]
        : OVERALL_CARD_TEMPLATES[metaMode];
}

/**
 * 言語に応じて詳細項目テンプレートを取得
 */
export function getDetailItemTemplate(metaMode: MetaMode, locale: Locale): string {
    return locale === "en"
        ? DETAIL_ITEM_TEMPLATES_EN[metaMode]
        : DETAIL_ITEM_TEMPLATES[metaMode];
}

/**
 * 言語に応じてドリルテンプレートを取得
 */
export function getDrillTemplateByLocale(locale: Locale): string {
    return locale === "en" ? DRILL_TEMPLATE_EN : DRILL_TEMPLATE;
}

/**
 * 言語に応じてペルソナ対応ドリルテンプレートを取得
 */
export function getDrillTemplateWithHint(drillToneHint: string, allowedEmojis: string[], locale: Locale): string {
    return locale === "en"
        ? getDrillTemplateEN(drillToneHint, allowedEmojis)
        : getDrillTemplate(drillToneHint, allowedEmojis);
}

/**
 * 言語に応じてJSON出力指示を取得
 */
export function getJsonOutputInstruction(locale: Locale): string {
    return locale === "en" ? JSON_OUTPUT_INSTRUCTION_EN : JSON_OUTPUT_INSTRUCTION;
}

/**
 * 言語に応じて今日のまとめテンプレートを取得
 */
export function getTodaySummaryTemplate(locale: Locale): string {
    return locale === "en" ? TODAY_SUMMARY_TEMPLATE_EN : TODAY_SUMMARY_TEMPLATE;
}
