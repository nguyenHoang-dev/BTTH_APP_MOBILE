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
  // Bắt lỗi body JSON sai cú pháp hoặc vượt giới hạn 50kb từ express.json()
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    return res.status(400).json({
      error: { message: 'Dữ liệu JSON gửi lên không đúng định dạng.' },
    });
  }
  if (err.type === 'entity.too.large') {
    return res.status(413).json({
      error: { message: 'Dữ liệu gửi lên vượt quá kích thước cho phép (50KB).' },
    });
  }

  const status = err.status || err.statusCode || 500;
  if (status >= 500) console.error('[ERROR]', err);
  return res.status(status).json({
    error: {
      // Không lộ chi tiết nội bộ (vd. API key, stack) ra client.
      message: status >= 500 ? 'Máy chủ AI đang gặp sự cố, vui lòng thử lại sau.' : err.message,
    },
  });
}

module.exports = { HttpError, notFound, errorHandler };

