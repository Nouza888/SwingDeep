/**
 * GolfScan AI - generateReport Callable関数
 *
 * Gemini APIへのプロキシ。iOS側で構築したプロンプトを受け取り、
 * Gemini APIを呼び出してレスポンスを返す。
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { v4 as uuidv4 } from "uuid";
import {
    validateRequest,
    GenerateReportRequest,
    GenerateReportResponse,
    ErrorCode,
} from "./validation";

// Secret Manager経由でAPIキーを取得
const geminiApiKey = defineSecret("GEMINI_API_KEY");

// Geminiモデル設定
const GEMINI_MODEL = "gemini-2.5-flash-lite";
const TIMEOUT_MS = 55000; // 55秒（Functions自体のタイムアウトより少し短く）

/**
 * generateReport - メインのCallable関数
 */
export const generateReport = onCall(
    {
        // v1.0は未認証許可（App Checkは1.1以降）
        enforceAppCheck: false,
        // シークレット使用
        secrets: [geminiApiKey],
        // メモリ・タイムアウト設定
        memory: "256MiB",
        timeoutSeconds: 60,
        // リージョン設定（日本ユーザー向け）
        region: "asia-northeast1",
    },
    async (request) => {
        const requestId = uuidv4();
        const startTime = Date.now();

        console.log(`[${requestId}] generateReport started`);

        try {
            // リクエストサイズを概算（正確ではないがDoS対策として）
            const rawBodySize = JSON.stringify(request.data).length;

            // バリデーション
            const validation = validateRequest(request.data, rawBodySize);

            if (!validation.valid) {
                console.error(
                    `[${requestId}] Validation failed: ${validation.errorMessage}`
                );

                // PAYLOAD_TOO_LARGEの場合はHTTPエラーとして返す
                if (validation.errorCode === "PAYLOAD_TOO_LARGE") {
                    throw new HttpsError(
                        "resource-exhausted",
                        validation.errorMessage || "Payload too large"
                    );
                }

                return createErrorResponse(
                    requestId,
                    validation.errorCode || "VALIDATION_ERROR",
                    validation.errorMessage || "Validation failed",
                    false
                );
            }

            const data = request.data as GenerateReportRequest;

            console.log(`[${requestId}] Calling Gemini API...`);
            console.log(`[${requestId}] Locale: ${validation.normalizedLocale}`);
            console.log(`[${requestId}] PersonaId: ${validation.normalizedPersonaId}`);
            console.log(`[${requestId}] PersonaFallback: ${validation.personaFallback}`);

            // Gemini API呼び出し
            const genAI = new GoogleGenerativeAI(geminiApiKey.value());
            const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

            // タイムアウト付きでAPI呼び出し
            const reportText = await Promise.race([
                callGeminiApi(model, data.systemPrompt, data.userPrompt),
                new Promise<never>((_, reject) =>
                    setTimeout(() => reject(new Error("TIMEOUT")), TIMEOUT_MS)
                ),
            ]);

            const duration = Date.now() - startTime;
            console.log(`[${requestId}] Gemini API success (${duration}ms)`);

            // 成功レスポンス
            const response: GenerateReportResponse = {
                success: true,
                requestId,
                provider: "gemini",
                personaFallback: validation.personaFallback || undefined,
                reportText,
            };

            return response;
        } catch (error) {
            const duration = Date.now() - startTime;
            console.error(`[${requestId}] Error after ${duration}ms:`, error);

            // エラーハンドリング
            if (error instanceof HttpsError) {
                throw error;
            }

            const errorMessage = error instanceof Error ? error.message : "Unknown error";

            // タイムアウト
            if (errorMessage === "TIMEOUT") {
                return createErrorResponse(
                    requestId,
                    "TIMEOUT",
                    "Request timed out. Please try again.",
                    true
                );
            }

            // Gemini API側のエラー
            if (errorMessage.includes("API") || errorMessage.includes("429")) {
                return createErrorResponse(
                    requestId,
                    "PROVIDER_ERROR",
                    "AI service temporarily unavailable. Please try again.",
                    true
                );
            }

            // その他のエラー
            return createErrorResponse(
                requestId,
                "UNKNOWN",
                "An unexpected error occurred. Please try again.",
                true
            );
        }
    }
);

/**
 * Gemini APIを呼び出す
 */
async function callGeminiApi(
    model: ReturnType<GoogleGenerativeAI["getGenerativeModel"]>,
    systemPrompt: string,
    userPrompt: string
): Promise<string> {
    const result = await model.generateContent({
        contents: [{ role: "user", parts: [{ text: userPrompt }] }],
        systemInstruction: { role: "system", parts: [{ text: systemPrompt }] },
        generationConfig: {
            responseMimeType: "application/json",
        },
    });

    const response = result.response;
    const text = response.text();

    if (!text) {
        throw new Error("Empty response from Gemini API");
    }

    return text;
}

/**
 * エラーレスポンスを生成
 */
function createErrorResponse(
    requestId: string,
    code: ErrorCode,
    message: string,
    retryable: boolean
): GenerateReportResponse {
    return {
        success: false,
        requestId,
        provider: "gemini",
        error: {
            code,
            message,
            retryable,
        },
    };
}
