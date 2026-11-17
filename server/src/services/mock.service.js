/**
 * mock.service.js
 *
 * Dữ liệu giả lập khi server chưa cấu hình GEMINI_API_KEY (Demo Mode).
 * Nội dung đủ ý nghĩa theo category, không dùng prefix [DEMO] để tránh lộ chế độ demo.
 */

/** Map category → gợi ý tip tiếng Việt / Anh */
const CATEGORY_TIPS = {
  grammar: {
    vi: 'Hãy chú ý đến từ khóa tín hiệu thì (since/for/already/yesterday...) trước khi chọn.',
    en: 'Look for tense signal words (since, for, already, yesterday...) before choosing.',
  },
  vocabulary: {
    vi: 'Hãy học từ trong ngữ cảnh câu, không học riêng lẻ từng từ.',
    en: 'Learn words in sentence context rather than memorizing them in isolation.',
  },
  flutter: {
    vi: 'Đọc tài liệu Flutter chính thức tại docs.flutter.dev để hiểu rõ hơn.',
    en: 'Check the official Flutter docs at docs.flutter.dev for detailed explanations.',
  },
  network: {
    vi: 'Thực hành với Postman hoặc curl để hiểu rõ luồng HTTP request/response.',
    en: 'Practice with Postman or curl to understand the HTTP request/response cycle.',
  },
  dart: {
    vi: 'Thực hành trên DartPad (dartpad.dev) để nắm chắc cú pháp Dart.',
    en: 'Practice on DartPad (dartpad.dev) to solidify your Dart syntax knowledge.',
  },
};

const DEFAULT_TIP = {
  vi: 'Hãy ôn lại lý thuyết liên quan và làm thêm bài tập để củng cố kiến thức.',
  en: 'Review the related theory and practice more exercises to reinforce your knowledge.',
};

/**
 * Trả về giải thích mock (không dùng Gemini).
 * @param {{ selectedAnswer, correctAnswer, language, category? }} payload
 */
function buildMockExplanation({ selectedAnswer, correctAnswer, language, category }) {
  const tip = (CATEGORY_TIPS[category] || DEFAULT_TIP)[language === 'en' ? 'en' : 'vi'];

  if (language === 'en') {
    return {
      whyWrong: `"${selectedAnswer}" is not correct here. The question is testing a specific concept that this option does not satisfy.`,
      correctExplanation: `The correct answer is "${correctAnswer}". It directly matches what the question is asking about — review this concept to understand why.`,
      example: `When you see a similar question, focus on the key conditions and eliminate options that do not fit the context.`,
      tip,
    };
  }

  return {
    whyWrong: `"${selectedAnswer}" chưa đúng trong trường hợp này. Câu hỏi đang kiểm tra một khái niệm cụ thể mà đáp án này không thỏa mãn.`,
    correctExplanation: `Đáp án đúng là "${correctAnswer}". Nó khớp trực tiếp với yêu cầu của câu hỏi — hãy ôn lại khái niệm này để hiểu rõ hơn.`,
    example: `Khi gặp câu hỏi tương tự, hãy tập trung vào điều kiện then chốt và loại bỏ dần các đáp án không phù hợp với ngữ cảnh.`,
    tip,
  };
}

module.exports = { buildMockExplanation };

