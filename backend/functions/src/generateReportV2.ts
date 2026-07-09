/**
 * GolfScan AI - generateReportV2
 * Layer分離設計によるレポート生成
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { v4 as uuidv4 } from "uuid";

import {
    MetricKey,
    Severity,
    MetaMode,
    calculateMetaMode
} from "./severityThresholds";
import { getPersonaPrompt, getPersonaDefinition, getAvailablePersonaIds, PersonaId, selectPhrasesForPrompt, buildPhrasePromptSection } from "./personaPrompts";
import {
    FIRST_TIME_TEMPLATES,
    getOverallCardTemplate,
    getDetailItemTemplate,
    getDrillTemplateByLocale,
    getJsonOutputInstruction,
    getTodaySummaryTemplate,
    Locale
} from "./outputTemplates";
import {
    getDrillMaterial,
    selectDrill,
    detectSpineAngleDirection,
    detectSwingPathDirection,
    detectEarlyExtensionDirection,
    detectHeadMovementDirection,
    detectTempoDirection,
    detectHandPositionDirection,
    detectIntensity,
    DrillHistory
} from "./drillLibrary";
import { generateBadge } from "./badgeGenerator";
import { selectJudgmentTitle, selectJudgmentTitleWithTone, calculateDirection, MetricKey as JudgmentMetricKey } from "./judgmentTitles";

// Secret Manager
const geminiApiKey = defineSecret("GEMINI_API_KEY");

// --- Types ---

interface ItemRanked {
    key: MetricKey;
    display_name: string;
    severity: Severity;
    metrics: Record<string, unknown>;
}

// report_context の型定義
type ReportContext = "FIRST_TIME" | "GETTING_USED" | "REGULAR" | "COMEBACK";

interface GenerateReportV2Request {
    locale: "ja" | "en";
    persona_id: string;
    analysis_version: string;
    app_version: string;
    score: number;
    items_ranked: ItemRanked[];
    skeleton_summary_text: string;
    report_context?: ReportContext;  // ユーザーとの関係性フェーズ
    drill_history?: DrillHistory[];  // ドリル使用履歴（オプショナル）
}

interface DetailItem {
    key: string;
    judgment_title: string;  // 判定タイトル（7〜14文字）
    detail_text: string;
    detail_key_phrases: string[];  // 詳細コメント内の強調フレーズ（1〜2個）
    drill_intro_text: string;
    drill_title: string;
    drill_text: string;
    drill_key_phrases: string[];   // ドリル説明内の強調フレーズ（1〜2個）
    // プール式ドリル詳細（v2.0追加）
    drill_id?: string;
    drill_steps?: string[];
    drill_reps?: string;
    drill_tools?: string[]
    drill_ng?: string[];
    drill_variant_type?: string;
    drill_time_sec?: number;
    // v1.0レポート構成変更
    is_top2: boolean;        // 要改善順Top2かどうか
    item_score: number;      // 項目スコア（0-100）
}

interface GenerateReportV2Response {
    success: boolean;
    request_id: string;
    persona_id: string;
    analysis_version: string;
    locale: string;
    overall_badge_title: string;
    overall_card_text: string;
    details: DetailItem[];
    meta_mode: MetaMode;
    // v1.0レポート構成変更
    drills_to_show: string[];         // 表示すべきドリルのキーリスト（0〜2個）
    drill_section_message: string;    // ドリルセクション用固定メッセージ（ペルソナ別）
    token_usage?: { input_tokens: number; output_tokens: number };
    error?: { code: string; message: string; retryable: boolean };
}

// --- Helper Functions ---

/**
 * 項目のスコアを計算（0-100、高いほど良い）
 * severityベースで簡易計算
 */
function calculateItemScore(item: ItemRanked): number {
    // severityに基づいてスコアを計算
    switch (item.severity) {
        case "good":
            return 85;  // Good: 80-90
        case "ok":
            return 60;  // Check: 50-70
        case "bad":
            return 30;  // Bad: 20-40
        default:
            return 50;
    }
}

// --- Validation ---

function validateRequest(data: unknown): GenerateReportV2Request {
    const req = data as GenerateReportV2Request;

    // locale
    if (!["ja", "en"].includes(req.locale)) {
        throw new HttpsError("invalid-argument", "Invalid locale");
    }

    // persona_id (フォールバック対応)
    const availableIds = getAvailablePersonaIds();
    if (!availableIds.includes(req.persona_id as PersonaId)) {
        req.persona_id = "gentle_sister"; // フォールバック
    }

    // score
    if (typeof req.score !== "number" || req.score < 0 || req.score > 100) {
        throw new HttpsError("invalid-argument", "Invalid score");
    }

    // items_ranked
    if (!Array.isArray(req.items_ranked) || req.items_ranked.length !== 6) {
        throw new HttpsError("invalid-argument", "items_ranked must have 6 items");
    }

    return req;
}

// --- Report Context Rules ---

/**
 * report_context に応じた言語ルールを生成
 * LLMの距離感・踏み込み度・過去言及可否を制御
 */
function getReportContextRules(context: ReportContext, locale: string): string {
    const rules: Record<ReportContext, { ja: string; en: string }> = {
        FIRST_TIME: {
            ja: `【report_context: FIRST_TIME（初対面）】
- 「前回」「前より」「また」「いつも」などの時系列語は禁止
- 過去のスイングや改善への言及は禁止
- 今回のスイング単体の評価として、初見の印象のみを述べる
- 中立的で歓迎的な言葉遣いを使用
- 知っているフリは絶対にしない`,
            en: `【report_context: FIRST_TIME】
- Do NOT use words like "last time", "before", "again", "always"
- Do NOT reference past swings or improvement
- Frame observations as first impression only
- Use neutral, welcoming language
- Never pretend to know the user`
        },
        GETTING_USED: {
            ja: `【report_context: GETTING_USED（2〜3回目）】
- 「前回より良くなった」などの明確な比較は禁止
- 積み重ねを「匂わせる」表現は許可（例：「続けていく中で」「取り組みが」）
- 継続前提の言い回しは許可
- 少し親しみを出すが、踏み込みすぎない`,
            en: `【report_context: GETTING_USED】
- Avoid direct comparisons like "better than last time"
- You may imply consistency or emerging patterns
- Sound slightly more familiar, but not intimate
- May use phrases suggesting continuity`
        },
        REGULAR: {
            ja: `【report_context: REGULAR（常連）】
- 前回との比較OK
- 変化・成長への言及OK
- 踏み込んだコメントOK
- 簡潔で自信のある言葉遣いを使用
- 共有された文脈を慎重に仮定`,
            en: `【report_context: REGULAR】
- You may reference previous swings or changes
- You may mention growth or improvement
- Use concise, confident language
- Assume shared context carefully`
        },
        COMEBACK: {
            ja: `【report_context: COMEBACK（久しぶり）】
- 不在を批判しない
- 継続性と維持されている基礎を強調
- 新鮮なリスタートとしてレポートをフレーミング
- 「戻ってきてくれてありがとう」感を出す`,
            en: `【report_context: COMEBACK】
- Do NOT criticize absence
- Emphasize continuity and retained fundamentals
- Frame the report as a fresh restart
- Express appreciation for returning`
        }
    };

    return rules[context][locale === "ja" ? "ja" : "en"];
}

// --- Prompt Construction ---

function buildFullPrompt(
    req: GenerateReportV2Request,
    metaMode: MetaMode
): { systemPrompt: string; userPrompt: string } {
    const locale = req.locale;
    const reportContext = req.report_context || "FIRST_TIME";  // デフォルトはFIRST_TIME

    // Layer1: 人格OS（Block3で参照用）
    let layer1 = getPersonaPrompt(req.persona_id, locale);

    // フレーズ選択（サーバーサイドで3個程度を事前選択、言語設定に基づく）
    const personaDef = getPersonaDefinition(req.persona_id);
    const selectedPhrases = selectPhrasesForPrompt(personaDef, metaMode, locale);
    if (selectedPhrases.length > 0) {
        layer1 += buildPhrasePromptSection(selectedPhrases, locale);
    }

    // Layer2: 出力構造（metaモード別、言語設定に対応）
    const layer2Overall = getOverallCardTemplate(metaMode, locale as Locale);
    const layer2Detail = getDetailItemTemplate(metaMode, locale as Locale);
    const layer2Drill = getDrillTemplateByLocale(locale as Locale);

    // report_context ルール
    const contextRules = getReportContextRules(reportContext, locale);

    // ペルソナ定義からドリルトーンヒント取得
    const drillToneHint = personaDef.drillToneHint[locale] || personaDef.drillToneHint.ja || "";

    // ドリル素材を整形（プール式ドリル対応）
    const drillHistory = req.drill_history || [];

    // ヘルパー関数：プール式ドリルを選択
    const getPoolDrill = (key: string, primaryValue: number, severity: Severity) => {
        const intensity = detectIntensity(severity);

        if (key === "spine_angle") {
            const direction = detectSpineAngleDirection(primaryValue);
            return selectDrill("spine_angle", direction, intensity, locale, drillHistory);
        }
        if (key === "swing_path") {
            const direction = detectSwingPathDirection(primaryValue);
            return selectDrill("swing_path", direction, intensity, locale, drillHistory);
        }
        if (key === "early_extension") {
            const direction = detectEarlyExtensionDirection(primaryValue);
            return selectDrill("early_extension", direction, intensity, locale, drillHistory);
        }
        if (key === "head_movement") {
            const direction = detectHeadMovementDirection(primaryValue);
            return selectDrill("head_movement", direction, intensity, locale, drillHistory);
        }
        if (key === "tempo") {
            const direction = detectTempoDirection(primaryValue);
            return selectDrill("tempo", direction, intensity, locale, drillHistory);
        }
        if (key === "hand_position") {
            const direction = detectHandPositionDirection(primaryValue);
            return selectDrill("hand_position", direction, intensity, locale, drillHistory);
        }
        return null;
    };

    const drillMaterials = req.items_ranked.map(item => {
        const metricValues = Object.values(item.metrics) as number[];
        const primaryValue = metricValues.length > 0 ? metricValues[0] : 0;

        // プール式ドリル対応メトリクスの場合
        const poolDrill = getPoolDrill(item.key, primaryValue, item.severity);
        if (poolDrill) {
            return `- ${item.display_name}:
    [POOL_DRILL] drill_id="${poolDrill.drill_id}"
    タイトル: 「${poolDrill.title}」
    目的: ${poolDrill.intent}
    注意点: ${poolDrill.ng[0] || "なし"}
    ※上記情報を元に、ペルソナの文体でユーザーを励ます魅力的な導入文を3〜4行で作成してください。
    ※ペルソナ文体ヒント: ${drillToneHint}`;
        }

        // レガシーフォールバック
        const material = getDrillMaterial(item.key, locale);
        if (!material) {
            return `- ${item.display_name}: ドリル未設定`;
        }
        return `- ${item.display_name}: 「${material.title}」 ${material.baseInstruction}`;
    }).join("\n");

    // 初回演出（FIRST_TIME専用）
    const firstTimeGreeting = reportContext === "FIRST_TIME"
        ? FIRST_TIME_TEMPLATES.greetings[locale][metaMode]
        : "";

    // ============================================
    // 3ブロック構造プロンプト
    // ============================================

    // ペルソナ別のプロンプト用情報（personaDefは先に取得済み）
    const personaShortDesc = personaDef.shortDesc[locale] || personaDef.shortDesc.ja || "ゴルフコーチAI";
    const emojiRule = personaDef.emojiRule[locale] || personaDef.emojiRule.ja || "絵文字は控えめに";

    // Block 1: 人格 + 禁止/必須ルール（最優先・冒頭5〜10行）
    // 👉 LLMが最も重視する位置。文体制御・禁止事項・キャラ性を集約
    const block1_persona_rules = `
あなたは${personaShortDesc}

【絶対禁止】
・「まるで」← 一度も使わない
・医療/診断を連想する言葉
・箇条書きの多用
・絵文字の直後に「。」← 「〜ですね✨。」は不自然。「〜ですね✨」が正しい

【必須】
・比喩は「〜のように」「〜みたいに」で表現
・絵文字は1つの詳細コメントや1つのドリル説明につき2個程度使う。少なすぎは禁止
・${emojiRule}
・${reportContext === "FIRST_TIME" ? "初対面なので冒頭で挨拶" : reportContext === "COMEBACK" ? "久しぶりの再会を温かく迎える" : "継続ユーザーとして自然に話す"}
・会話口調の自然な日本語。教科書調禁止
`;

    // Block 2: 出力構造ルール
    // 👉 何をどの順番で出力するかの構造
    const block2_structure = `
【出力構造】
1. overall_card_text: ${reportContext === "FIRST_TIME" ? "挨拶から始める。" : ""}全体の印象を4〜6行で。
2. details[6件]: 各項目の説明（judgment_titleを自然に回収）
3. drill: 改善ドリルの説明

【tone別の踏み込み度】
SOFT=観察的・共感的、NORMAL=明確・説明的、HARD=率直・本音
`;

    // Block 3: 詳細ロジック・分析データ（長くてOK）
    // 👉 severity, direction, tone, report_context等の技術情報
    const block3_details = `
【ペルソナ詳細】
${layer1}

---

${layer2Overall}

---

${layer2Detail}

---

${layer2Drill}

---

${getTodaySummaryTemplate(locale as Locale)}

---

【report_context】
${contextRules}

${firstTimeGreeting ? `【初回演出テンプレ】\n${firstTimeGreeting}` : ""}

---

${getJsonOutputInstruction(locale as Locale)}
`;

    // 最終プロンプト = Block1 + Block2 + Block3
    const systemPrompt = `${block1_persona_rules}

---

${block2_structure}

---

${block3_details}
`;

    // Layer3: データ（ユーザープロンプト）
    // 各項目にtoneとjudgment_titleを事前計算
    const itemsFormatted = req.items_ranked.map((item, i) => {
        const severityLabel = {
            good: locale === "ja" ? "良好" : "Good",
            ok: locale === "ja" ? "要注意" : "Needs Attention",
            bad: locale === "ja" ? "要改善" : "Needs Improvement"
        }[item.severity];

        // direction計算
        const metricValues = Object.values(item.metrics) as number[];
        const primaryValue = metricValues.length > 0 ? metricValues[0] : 0;
        const direction = calculateDirection(item.key as JudgmentMetricKey, primaryValue);

        // judgment_titleとtoneを選択
        const { title: judgmentTitle, tone } = selectJudgmentTitleWithTone(
            item.key as JudgmentMetricKey,
            item.severity as "good" | "ok" | "bad",
            direction,
            reportContext as "FIRST_TIME" | "GETTING_USED" | "REGULAR" | "COMEBACK",
            locale
        );

        return `${i + 1}. ${item.display_name} [${severityLabel}]
   Judgment Title: 「${judgmentTitle}」
   Tone: ${tone}
   Metrics: ${JSON.stringify(item.metrics)}`;
    }).join("\n\n");

    const userPrompt = `
## スイング分析データ（${locale === "ja" ? "日本語で出力" : "Output in English"}）

スコア: ${req.score}点
モード: ${metaMode}
report_context: ${reportContext}

### 項目一覧（危険度順）
${itemsFormatted}

### ドリル素材
${drillMaterials}

### 要約
${req.skeleton_summary_text}

---

上記データに基づいて、JSONのみを出力してください。
report_contextのルールを必ず遵守すること。
`;

    return { systemPrompt, userPrompt };
}

// --- LLM Call ---

async function callGemini(
    apiKey: string,
    systemPrompt: string,
    userPrompt: string
): Promise<string> {
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
        model: "gemini-2.5-flash-lite",  // Gemini 2.5 Flash-Lite に統一
        generationConfig: {
            responseMimeType: "application/json",
        }
    });

    const result = await model.generateContent({
        contents: [{ role: "user", parts: [{ text: userPrompt }] }],
        systemInstruction: { role: "system", parts: [{ text: systemPrompt }] },
    });

    const response = result.response;
    const text = response.text();

    if (!text) {
        throw new Error("Empty response from Gemini API");
    }

    return text;
}

// --- Quality Check ---

const FORBIDDEN_WORDS = [
    "診断", "診察", "治療", "病院", "医師", "怪我", "損傷", "炎症",
    "diagnosis", "treatment", "hospital", "doctor", "injury", "inflammation"
];

function qualityCheck(
    overallText: string,
    details: DetailItem[],
    locale: string
): { passed: boolean; reason?: string } {
    // 1. overall_card_text が4〜6行
    const lines = overallText.split("\n").filter(l => l.trim().length > 0);
    if (lines.length < 3 || lines.length > 8) {
        return { passed: false, reason: "overall_card_text line count out of range" };
    }

    // 2. details が6件
    if (details.length !== 6) {
        return { passed: false, reason: "details count is not 6" };
    }

    // 3. 禁止語チェック
    const allText = overallText + details.map(d => d.detail_text + d.drill_text).join(" ");
    for (const word of FORBIDDEN_WORDS) {
        if (allText.includes(word)) {
            return { passed: false, reason: `Forbidden word found: ${word}` };
        }
    }

    // 4. detail_text が長すぎない（800文字以下）
    for (const detail of details) {
        if (detail.detail_text.length > 800) {
            return { passed: false, reason: `detail_text too long: ${detail.key}` };
        }
    }

    return { passed: true };
}

// --- Main Function ---

export const generateReportV2 = onCall(
    {
        region: "asia-northeast1",
        timeoutSeconds: 120,
        memory: "512MiB",
        secrets: [geminiApiKey],
    },
    async (request): Promise<GenerateReportV2Response> => {
        const requestId = uuidv4();


        try {
            // Validation
            const req = validateRequest(request.data);
            const locale = req.locale;
            const reportContext = req.report_context || "FIRST_TIME";

            // Calculate meta mode
            const severities = req.items_ranked.map(item => item.severity);
            const metaMode = calculateMetaMode(severities);

            // Generate badge
            const topIssueKey = req.items_ranked.find(item => item.severity !== "good")?.key || null;
            const badgeTitle = generateBadge(req.score, topIssueKey, metaMode, locale, Date.now() % 5);

            // Build prompt
            const { systemPrompt, userPrompt } = buildFullPrompt(req, metaMode);

            // Call LLM (with retry)
            let llmResponse: string;
            let parsedResponse: { overall_card_text: string; details: DetailItem[] };
            let retryCount = 0;
            const maxRetries = 1;

            while (retryCount <= maxRetries) {
                try {
                    llmResponse = await callGemini(geminiApiKey.value(), systemPrompt, userPrompt);
                    parsedResponse = JSON.parse(llmResponse);

                    // Quality check
                    const qc = qualityCheck(parsedResponse.overall_card_text, parsedResponse.details, locale);
                    if (!qc.passed) {
                        console.warn(`Quality check failed: ${qc.reason}, retry ${retryCount + 1}`);
                        retryCount++;
                        continue;
                    }

                    break;
                } catch (e) {
                    console.error(`LLM call failed: ${e}, retry ${retryCount + 1}`);
                    retryCount++;
                    if (retryCount > maxRetries) {
                        throw e;
                    }
                }
            }

            // Add judgment titles to details (with direction + tone control)
            // Also enforce key from items_ranked (don't rely on LLM response)
            // v1.0: スコア順でTop2判定、ドリル表示ロジック追加
            const drillHistory = req.drill_history || [];

            // items_rankedをスコア順（低い順=要改善順）にソート
            const sortedItemsWithIndex = req.items_ranked.map((item, index) => ({
                item,
                originalIndex: index
            })).sort((a, b) => {
                // スコアを計算（metricsの値から）
                const scoreA = calculateItemScore(a.item);
                const scoreB = calculateItemScore(b.item);
                return scoreA - scoreB;  // 低いスコアが先（要改善順）
            });

            const detailsWithTitles = sortedItemsWithIndex.map((sorted, sortedIndex) => {
                const { item, originalIndex } = sorted;
                const detail = parsedResponse!.details[originalIndex];

                // Calculate direction from metrics value
                // Use primary metric value (first value in metrics object)
                const metricValues = Object.values(item.metrics) as number[];
                const primaryValue = metricValues.length > 0 ? metricValues[0] : 0;
                const direction = calculateDirection(
                    item.key as JudgmentMetricKey,
                    primaryValue
                );

                // Select judgment title with tone control based on report_context
                const judgmentTitle = selectJudgmentTitle(
                    item.key as JudgmentMetricKey,
                    item.severity as "good" | "ok" | "bad",
                    direction,
                    reportContext as "FIRST_TIME" | "GETTING_USED" | "REGULAR" | "COMEBACK",
                    locale
                );

                // Pool-based drill selection for supported metrics
                let drillData: Partial<DetailItem> = {};
                const poolMetrics = ["spine_angle", "swing_path", "early_extension", "head_movement", "tempo", "hand_position"];
                if (poolMetrics.includes(item.key)) {
                    const intensity = detectIntensity(item.severity);
                    let selectedDrill = null;

                    if (item.key === "spine_angle") {
                        const direction = detectSpineAngleDirection(primaryValue);
                        selectedDrill = selectDrill("spine_angle", direction, intensity, locale, drillHistory);
                    } else if (item.key === "swing_path") {
                        const direction = detectSwingPathDirection(primaryValue);
                        selectedDrill = selectDrill("swing_path", direction, intensity, locale, drillHistory);
                    } else if (item.key === "early_extension") {
                        const direction = detectEarlyExtensionDirection(primaryValue);
                        selectedDrill = selectDrill("early_extension", direction, intensity, locale, drillHistory);
                    } else if (item.key === "head_movement") {
                        const direction = detectHeadMovementDirection(primaryValue);
                        selectedDrill = selectDrill("head_movement", direction, intensity, locale, drillHistory);
                    } else if (item.key === "tempo") {
                        const direction = detectTempoDirection(primaryValue);
                        selectedDrill = selectDrill("tempo", direction, intensity, locale, drillHistory);
                    } else if (item.key === "hand_position") {
                        const direction = detectHandPositionDirection(primaryValue);
                        selectedDrill = selectDrill("hand_position", direction, intensity, locale, drillHistory);
                    }

                    if (selectedDrill) {
                        // LLM生成のdrill_intro_textは保持し、タイトルとsteps等のみ上書き
                        drillData = {
                            drill_id: selectedDrill.drill_id,
                            drill_title: selectedDrill.title,
                            // drill_text: detail.drill_intro_text を使用（LLM生成）
                            drill_steps: selectedDrill.steps,
                            drill_reps: selectedDrill.reps,
                            drill_tools: selectedDrill.tools,
                            drill_ng: selectedDrill.ng,
                            drill_variant_type: selectedDrill.variant_type,
                            drill_time_sec: selectedDrill.time_sec
                        };
                    }
                }

                // v1.0: is_top2とitem_scoreを追加
                const itemScore = calculateItemScore(item);
                const isTop2 = sortedIndex < 2;

                return {
                    ...detail,
                    key: item.key,  // Force key from items_ranked (reliable source)
                    judgment_title: judgmentTitle,
                    is_top2: isTop2,
                    item_score: itemScore,
                    // キーフレーズ（LLM生成、デフォルトは空配列）
                    detail_key_phrases: detail.detail_key_phrases || [],
                    drill_key_phrases: detail.drill_key_phrases || [],
                    // drill_intro_textはLLM生成のものを使う、他のフィールドはプール式
                    ...drillData  // Override with pool-based drill for supported metrics
                };
            });

            // v1.0: ドリル表示ロジック（機械判定）
            const badCheckItems = detailsWithTitles.filter(d => {
                const item = req.items_ranked.find(i => i.key === d.key);
                return item && (item.severity === "bad" || item.severity === "ok");
            });

            let drillsToShow: string[] = [];
            if (badCheckItems.length >= 2) {
                drillsToShow = detailsWithTitles.filter(d => d.is_top2).map(d => d.key);
            } else if (badCheckItems.length === 1) {
                drillsToShow = [badCheckItems[0].key];
            }
            // 全Good → drillsToShow = []

            // v1.0: ドリルセクション固定メッセージ（ペルソナ別プールからランダム選択）
            const personaDef = getPersonaDefinition(req.persona_id);
            let drillSectionMessage = "";
            if (drillsToShow.length === 0) {
                // 全Good
                const messages = personaDef.drillNoneMessages[locale] || personaDef.drillNoneMessages.ja;
                drillSectionMessage = messages[Math.floor(Math.random() * messages.length)];
            } else if (drillsToShow.length === 1) {
                // 1本のみ
                const messages = personaDef.drillSingleMessages[locale] || personaDef.drillSingleMessages.ja;
                drillSectionMessage = messages[Math.floor(Math.random() * messages.length)];
            }
            // 2本 → メッセージなし

            // Success response
            return {
                success: true,
                request_id: requestId,
                persona_id: req.persona_id,
                analysis_version: req.analysis_version,
                locale: locale,
                overall_badge_title: badgeTitle,
                overall_card_text: parsedResponse!.overall_card_text,
                details: detailsWithTitles,
                meta_mode: metaMode,
                drills_to_show: drillsToShow,
                drill_section_message: drillSectionMessage,
            };

        } catch (error) {
            console.error(`generateReportV2 error: ${error}`);

            const isRetryable = error instanceof Error &&
                (error.message.includes("timeout") || error.message.includes("network"));

            return {
                success: false,
                request_id: requestId,
                persona_id: "",
                analysis_version: "",
                locale: "",
                overall_badge_title: "",
                overall_card_text: "",
                details: [],
                meta_mode: "NORMAL",
                drills_to_show: [],
                drill_section_message: "",
                error: {
                    code: "PROVIDER_ERROR",
                    message: error instanceof Error ? error.message : "Unknown error",
                    retryable: isRetryable,
                },
            };
        }
    }
);
