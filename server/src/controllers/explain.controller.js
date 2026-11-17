const geminiService = require('../services/gemini.service');
const { HttpError } = require('../middlewares/error.middleware');

const MAX_TEXT = 1000;
const VALID_LANGUAGES = ['vi', 'en'];
const VALID_CATEGORIES = ['grammar', 'vocabulary', 'flutter', 'network', 'dart'];

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
 *   "question":       "string",
 *   "options":        ["A", "B", "C", "D"],
 *   "selectedAnswer": "string",
 *   "correctAnswer":  "string",
 *   "language":       "vi" | "en"          (mặc định "vi")
 *   "category":       "grammar" | "vocabulary" | "flutter" | "network" | "dart"  (optional)
 * }
 */
async function explainAnswer(req, res, next) {
  try {
    const body = req.body || {};
    const payload = {
      question:       requireString(body, 'question'),
      selectedAnswer: requireString(body, 'selectedAnswer'),
      correctAnswer:  requireString(body, 'correctAnswer'),
      options: Array.isArray(body.options)
        ? body.options.filter((o) => typeof o === 'string').slice(0, 6)
        : [],
      language: VALID_LANGUAGES.includes(body.language) ? body.language : 'vi',
      // category là optional – dùng cho mock thông minh hơn theo chủ đề
      category: VALID_CATEGORIES.includes(body.category) ? body.category : undefined,
    };

    const result = await geminiService.explain(payload);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

module.exports = { explainAnswer };

