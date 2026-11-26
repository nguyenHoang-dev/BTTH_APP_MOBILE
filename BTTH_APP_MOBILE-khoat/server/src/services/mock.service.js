/** Dữ liệu giả lập khi server chưa cấu hình GEMINI_API_KEY. */
function buildMockExplanation({ selectedAnswer, correctAnswer, language }) {
  if (language === 'en') {
    return {
      whyWrong: `[DEMO] "${selectedAnswer}" is incorrect because it does not satisfy the key condition of the question.`,
      correctExplanation: `[DEMO] The correct answer is "${correctAnswer}" since it matches the definition being asked.`,
      example: '[DEMO] Example: "She has lived here since 2010" uses present perfect, not past simple.',
      tip: '[DEMO] Look for signal words (since, for, already...) before choosing.',
    };
  }
  return {
    whyWrong: `[DEMO] "${selectedAnswer}" sai vì không thỏa điều kiện chính mà câu hỏi yêu cầu.`,
    correctExplanation: `[DEMO] Đáp án đúng là "${correctAnswer}" vì khớp với định nghĩa được hỏi.`,
    example: '[DEMO] Ví dụ: "She has lived here since 2010" dùng hiện tại hoàn thành, không dùng quá khứ đơn.',
    tip: '[DEMO] Hãy tìm từ khóa tín hiệu (since, for, already...) trước khi chọn.',
  };
}

module.exports = { buildMockExplanation };

