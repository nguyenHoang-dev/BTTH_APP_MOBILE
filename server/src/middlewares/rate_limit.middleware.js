const env = require('../config/env');
const { HttpError } = require('./error.middleware');

/**
 * Bộ giới hạn lượt gọi (Fixed Window Rate Limiter) theo IP.
 *
 * Bảo vệ hạn mức GEMINI_API_KEY trước các kịch bản spam request hoặc vòng lặp lỗi từ client.
 * Mặc định: tối đa 15 lượt gọi / 60 giây trên mỗi địa chỉ IP.
 */
function createRateLimiter({
  windowMs = env.rateLimitWindowMs,
  maxRequests = env.rateLimitMaxRequests,
  maxTrackedIps = 5000,
} = {}) {
  /** @type {Map<string, { count: number, resetAt: number }>} */
  const buckets = new Map();

  // Dọn dẹp định kỳ các IP đã hết hạn để tránh rò rỉ bộ nhớ (memory leak) khi chạy lâu dài.
  const cleanupTimer = setInterval(() => {
    const now = Date.now();
    for (const [ip, record] of buckets.entries()) {
      if (now >= record.resetAt) {
        buckets.delete(ip);
      }
    }
  }, windowMs);

  // Không giữ event loop của Node.js khi đóng server hoặc chạy test.
  if (typeof cleanupTimer.unref === 'function') {
    cleanupTimer.unref();
  }

  function rateLimitMiddleware(req, res, next) {
    // Sử dụng req.ip chuẩn của Express (chống giả mạo header X-Forwarded-For khi không qua reverse proxy).
    const clientIp = req.ip || req.socket?.remoteAddress || 'unknown';

    const now = Date.now();
    let record = buckets.get(clientIp);

    if (!record || now >= record.resetAt) {
      // Bảo vệ RAM nếu bị flood từ hàng ngàn IP khác nhau.
      if (buckets.size >= maxTrackedIps && !buckets.has(clientIp)) {
        const oldestKey = buckets.keys().next().value;
        if (oldestKey !== undefined) buckets.delete(oldestKey);
      }
      record = { count: 0, resetAt: now + windowMs };
      buckets.set(clientIp, record);
    }

    record.count += 1;

    const remaining = Math.max(0, maxRequests - record.count);
    const retryAfterSec = Math.max(1, Math.ceil((record.resetAt - now) / 1000));

    res.setHeader('X-RateLimit-Limit', String(maxRequests));
    res.setHeader('X-RateLimit-Remaining', String(remaining));
    res.setHeader('X-RateLimit-Reset', String(Math.ceil(record.resetAt / 1000)));

    if (record.count > maxRequests) {
      res.setHeader('Retry-After', String(retryAfterSec));
      return next(
        new HttpError(
          429,
          `Bạn đã gọi AI quá nhiều lần (tối đa ${maxRequests} lần/phút). Vui lòng thử lại sau ${retryAfterSec} giây.`,
        ),
      );
    }

    return next();
  }

  // Cho phép xóa bộ nhớ trong unit test khi cần.
  rateLimitMiddleware.reset = () => buckets.clear();

  return rateLimitMiddleware;
}

const aiRateLimiter = createRateLimiter();

module.exports = { createRateLimiter, aiRateLimiter };

