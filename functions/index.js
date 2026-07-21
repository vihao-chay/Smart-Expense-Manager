const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

const geminiApiKey = defineSecret("GEMINI_API_KEY");

const region = "asia-southeast1";
const defaultModel = "gemini-3.5-flash";
const maxPromptLength = 12000;

exports.generateaiinsights = onCall(
  {
    region,
    timeoutSeconds: 60,
    memory: "256MiB",
    secrets: [geminiApiKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Bạn cần đăng nhập trước khi dùng AI.",
      );
    }

    const prompt = sanitizePrompt(request.data?.prompt);
    const model = sanitizeModel(request.data?.model);
    const apiKey = geminiApiKey.value();

    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": apiKey,
          },
          body: JSON.stringify({
            contents: [
              {
                parts: [{ text: prompt }],
              },
            ],
            generationConfig: {
              temperature: 0.35,
              maxOutputTokens: 800,
            },
          }),
        },
      );

      const bodyText = await response.text();
      const decoded = parseJson(bodyText);

      if (!response.ok) {
        logger.error("Gemini API error", {
          uid: request.auth.uid,
          status: response.status,
          body: decoded ?? bodyText,
        });
        throw new HttpsError(
          "internal",
          geminiErrorMessage(decoded, response.status),
        );
      }

      const text = extractGeminiText(decoded);
      if (!text) {
        logger.error("Gemini empty response", {
          uid: request.auth.uid,
          body: decoded ?? bodyText,
        });
        throw new HttpsError(
          "internal",
          "Gemini chưa trả về nội dung phân tích.",
        );
      }

      return { text, model };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error("generateaiinsights failed", {
        uid: request.auth.uid,
        error,
      });
      throw new HttpsError("internal", "Không thể tạo phân tích AI lúc này.");
    }
  },
);

function sanitizePrompt(value) {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "Prompt AI không hợp lệ.");
  }

  const prompt = value.trim();
  if (!prompt) {
    throw new HttpsError("invalid-argument", "Prompt AI không được để trống.");
  }
  if (prompt.length > maxPromptLength) {
    throw new HttpsError(
      "invalid-argument",
      "Dữ liệu gửi lên AI quá dài. Hãy giảm khoảng thời gian thống kê.",
    );
  }
  return prompt;
}

function sanitizeModel(value) {
  if (typeof value !== "string" || !value.trim()) return defaultModel;
  const model = value.trim();
  if (!/^[a-zA-Z0-9_.-]+$/.test(model)) return defaultModel;
  return model;
}

function parseJson(value) {
  try {
    return JSON.parse(value);
  } catch (_) {
    return null;
  }
}

function extractGeminiText(decoded) {
  const parts = decoded?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return "";
  return parts
    .map((part) => (typeof part.text === "string" ? part.text : ""))
    .join("\n")
    .trim();
}

function geminiErrorMessage(decoded, status) {
  const message = decoded?.error?.message;
  if (typeof message === "string" && message.trim()) return message.trim();
  return `Gemini API lỗi ${status}.`;
}
