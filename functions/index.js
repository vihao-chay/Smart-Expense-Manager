const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const { initializeApp, getApps } = require("firebase-admin/app");
const { FieldValue, getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

if (getApps().length === 0) {
  initializeApp();
}

const geminiApiKey = defineSecret("GEMINI_API_KEY");

const region = "us-central1";
const defaultModel = "gemini-3.5-flash";
const maxPromptLength = 12000;
const defaultMaxOutputTokens = 2200;
const maxOutputTokenLimit = 3600;
const insightResponseSchema = {
  type: "OBJECT",
  properties: {
    insights: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          title: { type: "STRING" },
          analysis: { type: "STRING" },
          action: { type: "STRING" },
        },
        required: ["title", "analysis", "action"],
        propertyOrdering: ["title", "analysis", "action"],
      },
    },
  },
  required: ["insights"],
  propertyOrdering: ["insights"],
};

async function assertAdmin(uid) {
  const snapshot = await getFirestore().collection("users").doc(uid).get();
  const data = snapshot.data() || {};
  if (data.role !== "admin" || data.status === "locked") {
    throw new HttpsError(
      "permission-denied",
      "Chỉ admin đang hoạt động mới được gửi campaign.",
    );
  }
}

function sanitizeNotificationText(value, fieldName) {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} không hợp lệ.`);
  }
  const text = value.replace(/\s+/g, " ").trim();
  if (!text) {
    throw new HttpsError("invalid-argument", `${fieldName} không được trống.`);
  }
  if (text.length > 500) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} không được vượt quá 500 ký tự.`,
    );
  }
  return text;
}

function sanitizeCampaignType(value) {
  if (typeof value !== "string" || !value.trim()) return "campaign";
  return value.trim().slice(0, 40);
}

function sanitizeTargetType(value) {
  const targetType = typeof value === "string" ? value.trim() : "all";
  if (["all", "selected"].includes(targetType)) return targetType;
  return "all";
}

function sanitizeTargetUserIds(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => (typeof item === "string" ? item.trim() : ""))
    .filter(Boolean)
    .slice(0, 500);
}

function sanitizeDataMap(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const result = {};
  for (const [key, rawValue] of Object.entries(value)) {
    if (!/^[a-zA-Z0-9_]{1,40}$/.test(key)) continue;
    if (rawValue == null) continue;
    result[key] = String(rawValue).slice(0, 500);
  }
  return result;
}

async function loadCampaignUsers(db, targetType, targetUserIds) {
  if (targetType === "selected" && targetUserIds.length > 0) {
    const refs = targetUserIds.map((uid) => db.collection("users").doc(uid));
    const snapshots = await db.getAll(...refs);
    return snapshots.filter((doc) => {
      const data = doc.data() || {};
      return doc.exists && data.role !== "admin" && data.status !== "locked";
    });
  }

  const snapshot = await db.collection("users").get();
  return snapshot.docs.filter((doc) => {
    const data = doc.data() || {};
    return data.role !== "admin" && data.status !== "locked";
  });
}

async function loadUserTokens(db, userId) {
  const snapshot = await db
    .collection("users")
    .doc(userId)
    .collection("devices")
    .get();
  return snapshot.docs
    .map((doc) => doc.get("fcmToken"))
    .filter((token) => typeof token === "string" && token.trim())
    .map((token) => token.trim());
}

async function sendToTokens(tokens, payload) {
  let successCount = 0;
  let failureCount = 0;

  for (const tokenBatch of chunk(tokens, 500)) {
    const message = {
      tokens: tokenBatch,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: {
        type: payload.type,
        campaignId: payload.campaignId,
        notificationId: payload.notificationId,
        ...payload.data,
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    const result = await getMessaging().sendEachForMulticast(message);
    successCount += result.successCount;
    failureCount += result.failureCount;
  }

  return { successCount, failureCount };
}

function chunk(items, size) {
  const result = [];
  for (let index = 0; index < items.length; index += size) {
    result.push(items.slice(index, index + size));
  }
  return result;
}

exports.generateaiinsights = onCall(
  {
    region,
    timeoutSeconds: 90,
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
    const maxOutputTokens = sanitizeMaxOutputTokens(request.data?.maxOutputTokens);
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
            systemInstruction: {
              parts: [
                {
                  text:
                    "Bạn là chuyên gia phân tích tài chính cá nhân. " +
                    "Luôn trả lời bằng tiếng Việt. " +
                    "Tạo đúng 6 đến 8 mục phân tích. " +
                    "Mỗi mục phải có title, analysis và action. " +
                    "analysis phải có số liệu cụ thể; action phải là hành động thực tế. " +
                    "Không chỉ chào hỏi, không viết câu mở bài.",
                },
              ],
            },
            contents: [
              {
                parts: [{ text: prompt }],
              },
            ],
            generationConfig: {
              temperature: 0.45,
              topP: 0.95,
              maxOutputTokens,
              responseMimeType: "application/json",
              responseSchema: insightResponseSchema,
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

exports.sendNotificationCampaign = onCall(
  {
    region,
    timeoutSeconds: 90,
    memory: "512MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Bạn cần đăng nhập.");
    }

    await assertAdmin(request.auth.uid);

    const title = sanitizeNotificationText(request.data?.title, "Tiêu đề");
    const body = sanitizeNotificationText(request.data?.body, "Nội dung");
    const type = sanitizeCampaignType(request.data?.type);
    const targetType = sanitizeTargetType(request.data?.targetType);
    const targetUserIds = sanitizeTargetUserIds(request.data?.targetUserIds);
    const data = sanitizeDataMap(request.data?.data);

    const db = getFirestore();
    const campaignRef = db.collection("notificationCampaigns").doc();
    const campaignId = campaignRef.id;

    await campaignRef.set({
      title,
      body,
      type,
      targetType,
      targetUserIds,
      status: "sending",
      sentCount: 0,
      failedCount: 0,
      targetUserCount: 0,
      openedCount: 0,
      readCount: 0,
      createdBy: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const users = await loadCampaignUsers(db, targetType, targetUserIds);
    let sentCount = 0;
    let failedCount = 0;

    for (const userDoc of users) {
      const userId = userDoc.id;
      const notificationRef = db
        .collection("users")
        .doc(userId)
        .collection("notifications")
        .doc();

      await notificationRef.set({
        title,
        body,
        type,
        campaignId,
        isRead: false,
        data,
        createdAt: FieldValue.serverTimestamp(),
      });

      await campaignRef.collection("recipients").doc(userId).set({
        userId,
        notificationId: notificationRef.id,
        userEmail: userDoc.get("email") || null,
        userName: userDoc.get("fullName") || null,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });

      const tokens = await loadUserTokens(db, userId);
      if (tokens.length === 0) continue;

      const result = await sendToTokens(tokens, {
        title,
        body,
        type,
        campaignId,
        notificationId: notificationRef.id,
        data,
      });
      sentCount += result.successCount;
      failedCount += result.failureCount;
    }

    await campaignRef.set(
      {
        status: "sent",
        sentCount,
        failedCount,
        targetUserCount: users.length,
        sentAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { campaignId, targetUserCount: users.length, sentCount, failedCount };
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

function sanitizeMaxOutputTokens(value) {
  if (!Number.isInteger(value)) return defaultMaxOutputTokens;
  return Math.min(Math.max(value, 512), maxOutputTokenLimit);
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
  const rawText = parts
    .map((part) => (typeof part.text === "string" ? part.text : ""))
    .join("\n")
    .trim();

  const structured = parseJson(stripJsonFence(rawText));
  const formatted = formatStructuredInsights(structured);
  return formatted || rawText;
}

function stripJsonFence(value) {
  return value
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```$/i, "")
    .trim();
}

function formatStructuredInsights(value) {
  const insights = Array.isArray(value)
    ? value
    : Array.isArray(value?.insights)
      ? value.insights
      : [];
  if (insights.length === 0) return "";

  return insights
    .slice(0, 8)
    .map((item) => {
      const title = cleanInsightText(item?.title) || "Nhận xét";
      const analysis = cleanInsightText(item?.analysis);
      const action = cleanInsightText(item?.action);
      if (!analysis && !action) return "";
      return `- ${title}: ${analysis}${analysis && action ? " " : ""}${action}`;
    })
    .filter(Boolean)
    .join("\n");
}

function cleanInsightText(value) {
  if (typeof value !== "string") return "";
  return value.replace(/\s+/g, " ").trim();
}

function geminiErrorMessage(decoded, status) {
  const message = decoded?.error?.message;
  if (typeof message === "string" && message.trim()) return message.trim();
  return `Gemini API lỗi ${status}.`;
}
