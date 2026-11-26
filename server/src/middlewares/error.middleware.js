class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function notFound(req, res) {
  res.status(404).json({ error: { message: `Không tìm thấy ${req.method} ${req.originalUrl}` } });
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  const status = err.status || 500;
  if (status >= 500) console.error('[ERROR]', err);
  res.status(status).json({
    error: {
      // Không lộ chi tiết nội bộ (vd. API key, stack) ra client.
      message: status >= 500 ? 'Máy chủ AI đang gặp sự cố, vui lòng thử lại sau.' : err.message,
    },
  });
}

module.exports = { HttpError, notFound, errorHandler };

