require('dotenv').config();

const rawKey = (process.env.GEMINI_API_KEY || '').trim();
// Nếu người dùng copy nguyên file .env.example mà chưa thay key thật thì coi như chưa có key.
const isPlaceholderKey = rawKey === 'your_gemini_api_key_here';

const env = {
  port: Number(process.env.PORT) || 3000,
  geminiApiKey: isPlaceholderKey ? '' : rawKey,
  geminiModel: process.env.GEMINI_MODEL || 'gemini-2.5-flash',
  geminiTimeoutMs: Number(process.env.GEMINI_TIMEOUT_MS) || 12000,
  rateLimitWindowMs: Number(process.env.RATE_LIMIT_WINDOW_MS) || 60 * 1000,
  rateLimitMaxRequests: Number(process.env.RATE_LIMIT_MAX_REQUESTS) || 15,
};

/** Không có key => server tự động phục vụ dữ liệu demo thay vì lỗi. */
env.isDemoMode = env.geminiApiKey.length === 0;

module.exports = env;


