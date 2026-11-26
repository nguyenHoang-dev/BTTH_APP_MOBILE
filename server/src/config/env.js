require('dotenv').config();

const env = {
  port: Number(process.env.PORT) || 3000,
  geminiApiKey: (process.env.GEMINI_API_KEY || '').trim(),
  geminiModel: process.env.GEMINI_MODEL || 'gemini-2.5-flash',
  geminiTimeoutMs: Number(process.env.GEMINI_TIMEOUT_MS) || 12000,
};

/** Không có key => server tự động phục vụ dữ liệu demo thay vì lỗi. */
env.isDemoMode = env.geminiApiKey.length === 0;

module.exports = env;

