const geminiService = require('../services/gemini.service');
const { HttpError } = require('../middlewares/error.middleware');

const MAX_TEXT = 1000;

function requireString(body, field) {
  const value = body[field];
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new HttpError(400, `Thiếu hoặc sai trường "${field}"`);
  }
  if (value.length > MAX_TEXT) {
    throw new HttpError(400, `Trường "${field}" quá dài (tối đa ${MAX_TEXT} ký tự)`);
  }
  return value.trim();
}

/**
 * Body mong đợi:
 * {
 *   "question": "string",
 *   "options": ["A", "B", "C", "D"],
 *   "selectedAnswer": "string",
 *   "correctAnswer": "string",
 *   "language": "vi" | "en"
 * }
 */
async function explainAnswer(req, res, next) {
  try {
    const body = req.body || {};
    const payload = {
      question: requireString(body, 'question'),
      selectedAnswer: requireString(body, 'selectedAnswer'),
      correctAnswer: requireString(body, 'correctAnswer'),
      options: Array.isArray(body.options)
        ? body.options.filter((o) => typeof o === 'string').slice(0, 6)
        : [],
      language: body.language === 'en' ? 'en' : 'vi',
    };

    const result = await geminiService.explain(payload);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

module.exports = { explainAnswer };

