const env = require('../config/env');
const { buildExplainPrompt } = require('./prompt.builder');
const { buildMockExplanation } = require('./mock.service');
const { HttpError } = require('../middlewares/error.middleware');

const GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta/models';

/** Gemini đôi khi bọc JSON trong ```json ... ``` => bóc ra cho chắc. */
function parseModelJson(text) {
  const cleaned = text.replace(/```json|```/g, '').trim();
  try {
    return JSON.parse(cleaned);
  } catch {
    // Không parse được -> trả nguyên văn vào whyWrong để app vẫn hiển thị được.
    return { whyWrong: cleaned, correctExplanation: '', example: '', tip: '' };
  }
}

async function callGemini(prompt) {
  const url = `${GEMINI_BASE}/${env.geminiModel}:generateContent`;
  let response;
  try {
    // Node >= 18 có sẵn fetch + AbortSignal.timeout -> không cần SDK, server siêu nhẹ.
    response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': env.geminiApiKey, // Key chỉ tồn tại ở server.
      },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.4, responseMimeType: 'application/json' },
      }),
      signal: AbortSignal.timeout(env.geminiTimeoutMs),
    });
  } catch (err) {
    if (err.name === 'TimeoutError' || err.name === 'AbortError') {
      throw new HttpError(504, 'Gemini phản hồi quá lâu, vui lòng thử lại.');
    }
    throw new HttpError(502, 'Không kết nối được tới Gemini.');
  }

  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    console.error(`[Gemini] HTTP ${response.status}: ${detail.slice(0, 300)}`);
    if (response.status === 429) {
      throw new HttpError(429, 'AI đang quá tải (hết hạn mức), vui lòng thử lại sau ít phút.');
    }
    throw new HttpError(502, 'Dịch vụ AI tạm thời không khả dụng.');
  }

  const data = await response.json();
  const text = data?.candidates?.[0]?.content?.parts?.map((p) => p.text).join('') ?? '';
  if (!text) throw new HttpError(502, 'AI không trả về nội dung.');
  return text;
}

async function explain(payload) {
  if (env.isDemoMode) {
    return { source: 'demo', ...buildMockExplanation(payload) };
  }
  const text = await callGemini(buildExplainPrompt(payload));
  return { source: 'gemini', ...parseModelJson(text) };
}

module.exports = { explain };

