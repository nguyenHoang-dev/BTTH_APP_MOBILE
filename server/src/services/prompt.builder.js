/**
 * Prompt builder cho /api/explain
 * Tách hoàn toàn thành 2 hàm EN / VI để Gemini không bị lẫn lộn ngôn ngữ instruction.
 * Hỗ trợ cả 2 trường hợp:
 *  1. Người học chọn SAI (ResultScreen hoặc PracticeScreen) -> Giải thích vì sao sai + đáp án đúng + ví dụ.
 *  2. Người học chọn ĐÚNG (PracticeScreen bấm "Hỏi AI giải thích sâu hơn") -> Khẳng định đã chọn đúng, phân tích vì sao các đáp án khác sai + mở rộng kiến thức.
 * Mọi thay đổi prompt cần ghi lại trong docs/ai/.
 */

function _formatOptions(options) {
  return options.length
    ? options.map((o, i) => `${String.fromCharCode(65 + i)}. ${o}`).join('\n')
    : '(none)';
}

function _isSelectionCorrect(selectedAnswer, correctAnswer) {
  if (typeof selectedAnswer !== 'string' || typeof correctAnswer !== 'string') return false;
  return selectedAnswer.trim().toLowerCase() === correctAnswer.trim().toLowerCase();
}

/** Prompt hoàn toàn tiếng Anh */
function _buildEnglishPrompt({ question, options, selectedAnswer, correctAnswer }) {
  const isCorrect = _isSelectionCorrect(selectedAnswer, correctAnswer);
  const taskInstruction = isCorrect
    ? `The student selected the CORRECT answer ("${selectedAnswer}"). Confirm why "${correctAnswer}" is correct, briefly explain why the other options are distractors (put this in "whyWrong"), and provide an illustrative example.`
    : `Explain in detail why the student's answer ("${selectedAnswer}") is wrong compared to the correct answer ("${correctAnswer}") and provide an example.`;

  return `You are a bilingual (Vietnamese–English) quiz tutor.
Question: ${question}
Options:
${_formatOptions(options)}
Student's answer: ${selectedAnswer}
Correct answer: ${correctAnswer}

${taskInstruction}
Requirements:
- Reply entirely in English, concise and easy to understand (max ~200 words).
- Return ONLY valid JSON in this exact format:
{"whyWrong": "...", "correctExplanation": "...", "example": "...", "tip": "..."}`;
}

/** Prompt hoàn toàn tiếng Việt */
function _buildVietnamesePrompt({ question, options, selectedAnswer, correctAnswer }) {
  const isCorrect = _isSelectionCorrect(selectedAnswer, correctAnswer);
  const taskInstruction = isCorrect
    ? `Người học đã chọn ĐÚNG đáp án ("${selectedAnswer}"). Hãy giải thích chi tiết vì sao "${correctAnswer}" là đáp án đúng, phân tích ngắn gọn vì sao các phương án còn lại không phù hợp (đặt vào trường "whyWrong"), và đưa ra ví dụ minh họa.`
    : `Giải thích chi tiết tại sao đáp án này sai và đưa ra ví dụ.`;

  return `Bạn là gia sư ôn thi trắc nghiệm song ngữ Việt - Anh.
Câu hỏi: ${question}
Các lựa chọn:
${_formatOptions(options)}
Người học đã chọn: ${selectedAnswer}
Đáp án đúng: ${correctAnswer}

${taskInstruction}
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
