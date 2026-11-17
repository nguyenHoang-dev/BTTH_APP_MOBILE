/**
 * Prompt builder cho /api/explain
 * Tách hoàn toàn thành 2 hàm EN / VI để Gemini không bị lẫn lộn ngôn ngữ instruction.
 * Mọi thay đổi prompt cần ghi lại trong docs/ai/.
 */

function _formatOptions(options) {
  return options.length
    ? options.map((o, i) => `${String.fromCharCode(65 + i)}. ${o}`).join('\n')
    : '(none)';
}

/** Prompt hoàn toàn tiếng Anh */
function _buildEnglishPrompt({ question, options, selectedAnswer, correctAnswer }) {
  return `You are a bilingual (Vietnamese–English) quiz tutor.
Question: ${question}
Options:
${_formatOptions(options)}
Student's answer: ${selectedAnswer}
Correct answer: ${correctAnswer}

Explain in detail why the student's answer is wrong and provide an example.
Requirements:
- Reply entirely in English, concise and easy to understand (max ~200 words).
- Return ONLY valid JSON in this exact format:
{"whyWrong": "...", "correctExplanation": "...", "example": "...", "tip": "..."}`;
}

/** Prompt hoàn toàn tiếng Việt */
function _buildVietnamesePrompt({ question, options, selectedAnswer, correctAnswer }) {
  return `Bạn là gia sư ôn thi trắc nghiệm song ngữ Việt - Anh.
Câu hỏi: ${question}
Các lựa chọn:
${_formatOptions(options)}
Người học đã chọn: ${selectedAnswer}
Đáp án đúng: ${correctAnswer}

Giải thích chi tiết tại sao đáp án này sai và đưa ra ví dụ.
Yêu cầu:
- Trả lời bằng Tiếng Việt, ngắn gọn, dễ hiểu (tối đa ~200 từ).
- Trả về DUY NHẤT một JSON hợp lệ theo dạng:
{"whyWrong": "...", "correctExplanation": "...", "example": "...", "tip": "..."}`;
}

/**
 * Hàm chính – chọn prompt EN hoặc VI dựa vào language param.
 * @param {{ question, options, selectedAnswer, correctAnswer, language }} payload
 */
function buildExplainPrompt(payload) {
  if (payload.language === 'en') {
    return _buildEnglishPrompt(payload);
  }
  return _buildVietnamesePrompt(payload);
}

module.exports = { buildExplainPrompt };

