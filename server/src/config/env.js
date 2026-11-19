const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');

const envPath = path.resolve(__dirname, '../../.env');
const envExamplePath = path.resolve(__dirname, '../../.env.example');

// Tự động tạo sẵn file .env từ .env.example nếu máy của thành viên mới pull về chưa có file .env.
if (!fs.existsSync(envPath) && fs.existsSync(envExamplePath)) {
  try {
    fs.copyFileSync(envExamplePath, envPath);
  } catch {
    // Bỏ qua nếu không có quyền ghi file
  }
}

const PLACEHOLDER_KEYS = new Set([
  'your_gemini_api_key_here',
  'NHAP_KEY_GEMINI_CUA_BAN_VAO_DAY',
]);

function isRealApiKey(key) {
  return Boolean(key) && !PLACEHOLDER_KEYS.has(key);
}

function readValidKey(filePath) {
  if (!fs.existsSync(filePath)) return '';
  try {
    const parsed = dotenv.parse(fs.readFileSync(filePath));
    const k = (parsed.GEMINI_API_KEY || '').trim();
    return isRealApiKey(k) ? k : '';
  } catch {
    return '';
  }
}

dotenv.config({ path: envPath });
dotenv.config({ path: envExamplePath });

// Cho phép dán key vào bất kỳ file nào (.env hoặc dán thẳng vào .env.example đều nhận được ngay!)
const envKey = (process.env.GEMINI_API_KEY || '').trim();
const resolvedKey =
  (isRealApiKey(envKey) ? envKey : '') ||
  readValidKey(envPath) ||
  readValidKey(envExamplePath);

const env = {
  port: Number(process.env.PORT) || 3000,
  geminiApiKey: resolvedKey,
  geminiModel: process.env.GEMINI_MODEL || 'gemini-2.5-flash',
  geminiTimeoutMs: Number(process.env.GEMINI_TIMEOUT_MS) || 12000,
  rateLimitWindowMs: Number(process.env.RATE_LIMIT_WINDOW_MS) || 60 * 1000,
  rateLimitMaxRequests: Number(process.env.RATE_LIMIT_MAX_REQUESTS) || 15,
};

/** Không có key => server tự động phục vụ dữ liệu demo thay vì lỗi. */
env.isDemoMode = env.geminiApiKey.length === 0;

module.exports = env;


