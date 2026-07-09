/**
 * GolfScan AI - Firebase Functions 入力バリデーション
 */

// サポートされているロケール
export const VALID_LOCALES = ["en", "ja"] as const;
export type ValidLocale = typeof VALID_LOCALES[number];

// サポートされているペルソナID
export const VALID_PERSONA_IDS = {
    ja: ["normal_jp", "spartan_jp", "kind_jp", "kansai_mom_jp", "comedian_jp"],
    en: ["standard_en", "sergeant_en", "sister_en", "hero_en", "butler_en"],
} as const;

// デフォルトのペルソナID（フォールバック用）
export const DEFAULT_PERSONA_ID: Record<ValidLocale, string> = {
    ja: "normal_jp",
    en: "standard_en",
};

// サイズ制限
export const MAX_PROMPT_SIZE_BYTES = 50 * 1024; // 50KB
export const MAX_REQUEST_SIZE_BYTES = 100 * 1024; // 100KB

// エラーコード
export type ErrorCode =
    | "VALIDATION_ERROR"
    | "PAYLOAD_TOO_LARGE"
    | "RATE_LIMIT"
    | "PROVIDER_ERROR"
    | "TIMEOUT"
    | "UNKNOWN";

// リクエスト型
export interface GenerateReportRequest {
    clientId: string;
    locale: string;
    personaId: string;
    analysisVersion: string;
    appVersion: string;
    metrics: SwingMetrics;
    systemPrompt: string;
    userPrompt: string;
}

// メトリクス型
export interface SwingMetrics {
    spineAngleDiffDeg: number;
    hipMoveRatio: number;
    headMoveY: number;
    tempoRatio: number;
    handRaiseY: number;
    swingPathType: string;
}

// レスポンス型
export interface GenerateReportResponse {
    success: boolean;
    requestId: string;
    provider: "gemini";
    personaFallback?: boolean;
    reportText?: string;
    error?: {
        code: ErrorCode;
        message: string;
        retryable: boolean;
    };
}

// バリデーション結果
export interface ValidationResult {
    valid: boolean;
    personaFallback: boolean;
    normalizedLocale: ValidLocale;
    normalizedPersonaId: string;
    errorCode?: ErrorCode;
    errorMessage?: string;
}

/**
 * リクエストのバリデーションを実行
 */
export function validateRequest(
    data: unknown,
    rawBodySize: number
): ValidationResult {
    // 1. リクエスト全体のサイズチェック
    if (rawBodySize > MAX_REQUEST_SIZE_BYTES) {
        return {
            valid: false,
            personaFallback: false,
            normalizedLocale: "en",
            normalizedPersonaId: DEFAULT_PERSONA_ID.en,
            errorCode: "PAYLOAD_TOO_LARGE",
            errorMessage: `Request size (${rawBodySize} bytes) exceeds limit (${MAX_REQUEST_SIZE_BYTES} bytes)`,
        };
    }

    // 2. 型チェック
    if (!data || typeof data !== "object") {
        return {
            valid: false,
            personaFallback: false,
            normalizedLocale: "en",
            normalizedPersonaId: DEFAULT_PERSONA_ID.en,
            errorCode: "VALIDATION_ERROR",
            errorMessage: "Invalid request format",
        };
    }

    const req = data as GenerateReportRequest;

    // 3. 必須フィールドチェック
    if (!req.clientId || typeof req.clientId !== "string") {
        return {
            valid: false,
            personaFallback: false,
            normalizedLocale: "en",
            normalizedPersonaId: DEFAULT_PERSONA_ID.en,
            errorCode: "VALIDATION_ERROR",
            errorMessage: "Missing or invalid clientId",
        };
    }

    // 4. Localeの正規化
    let normalizedLocale: ValidLocale = "en";
    if (VALID_LOCALES.includes(req.locale as ValidLocale)) {
        normalizedLocale = req.locale as ValidLocale;
    }

    // 5. PersonaIdのバリデーションとフォールバック
    let normalizedPersonaId = req.personaId;
    let personaFallback = false;

    const validIds = VALID_PERSONA_IDS[normalizedLocale];
    if (!validIds.includes(req.personaId as never)) {
        normalizedPersonaId = DEFAULT_PERSONA_ID[normalizedLocale];
        personaFallback = true;
        console.log(
            `[Validation] PersonaId fallback: ${req.personaId} -> ${normalizedPersonaId}`
        );
    }

    // 6. プロンプトサイズチェック
    const systemPromptSize = Buffer.byteLength(req.systemPrompt || "", "utf8");
    const userPromptSize = Buffer.byteLength(req.userPrompt || "", "utf8");
    const totalPromptSize = systemPromptSize + userPromptSize;

    if (totalPromptSize > MAX_PROMPT_SIZE_BYTES) {
        return {
            valid: false,
            personaFallback,
            normalizedLocale,
            normalizedPersonaId,
            errorCode: "PAYLOAD_TOO_LARGE",
            errorMessage: `Prompt size (${totalPromptSize} bytes) exceeds limit (${MAX_PROMPT_SIZE_BYTES} bytes)`,
        };
    }

    // 7. Metricsの必須フィールドチェック
    if (!req.metrics || typeof req.metrics !== "object") {
        return {
            valid: false,
            personaFallback,
            normalizedLocale,
            normalizedPersonaId,
            errorCode: "VALIDATION_ERROR",
            errorMessage: "Missing or invalid metrics",
        };
    }

    return {
        valid: true,
        personaFallback,
        normalizedLocale,
        normalizedPersonaId,
    };
}
