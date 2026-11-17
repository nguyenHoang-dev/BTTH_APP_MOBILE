/**
 * rate_limit.middleware.js
 *
 * Giới hạn số request đến /api/explain để tránh spam,
 * đặc biệt khi Practice Mode gọi AI sau mỗi câu.
 *
 * Không dùng package ngoài – tự implement in-memory sliding window.
 * Phù hợp cho môi trường single-process (Node.js / Express đơn lẻ).
 */

const DEFAULT_WINDOW_MS = 60 * 1000; // 1 phút
const DEFAULT_MAX_REQUESTS = 20;     // 20 request / phút / IP

/** Map<ip, { count, resetAt }> */
const store = new Map();

/**
 * Tạo middleware rate limit.
 * @param {{ windowMs?: number, max?: number }} options
 */
function createRateLimiter({ windowMs = DEFAULT_WINDOW_MS, max = DEFAULT_MAX_REQUESTS } = {}) {
  // Dọn dẹp các entry cũ mỗi windowMs để tránh memory leak.
  const cleanup = setInterval(() => {
    const now = Date.now();
    for (const [key, record] of store.entries()) {
      if (record.resetAt <= now) store.delete(key);
    }
  }, windowMs);

  // Cho phép Node.js thoát dù interval còn sống.
  if (cleanup.unref) cleanup.unref();

  return function rateLimitMiddleware(req, res, next) {
    // Lấy IP: hỗ trợ proxy/load-balancer qua X-Forwarded-For.
    const ip =
      (req.headers['x-forwarded-for'] || '').split(',')[0].trim() ||
      req.socket?.remoteAddress ||
      'unknown';

    const now = Date.now();
    let record = store.get(ip);

    if (!record || record.resetAt <= now) {
      record = { count: 1, resetAt: now + windowMs };
      store.set(ip, record);
      return next();
    }

    record.count += 1;

    if (record.count > max) {
      const retryAfterSec = Math.ceil((record.resetAt - now) / 1000);
      res.setHeader('Retry-After', retryAfterSec);
      return res.status(429).json({
        error: {
          message: `Bạn đã gửi quá nhiều yêu cầu. Vui lòng thử lại sau ${retryAfterSec} giây.`,
        },
      });
    }

    return next();
  };
}

/** Middleware mặc định: 20 req / phút / IP – dùng ngay cho route explain. */
const explainRateLimiter = createRateLimiter();

module.exports = { createRateLimiter, explainRateLimiter };

