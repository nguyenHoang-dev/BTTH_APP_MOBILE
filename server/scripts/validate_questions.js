/**
 * validate_questions.js
 * Chạy: node server/scripts/validate_questions.js
 *
 * Kiểm tra toàn bộ assets/data/questions.json trước khi commit.
 */

const fs = require('fs');
const path = require('path');

const QUESTIONS_PATH = path.resolve(__dirname, '../../mobile/assets/data/questions.json');
const REQUIRED_TOTAL = 300;
const VALID_CATEGORIES = [
  'grammar',
  'vocabulary',
  'flutter',
  'network',
  'dart',
  'Khối 1. Ngôn ngữ Dart',
  'Khối 2. Môi trường và công cụ',
  'Khối 3. Cách Flutter hoạt động',
  'Khối 4. Bố cục và cuộn',
  'Khối 5. Thiết kế và giao diện chung',
  'Khối 6. Thích ứng và co giãn',
  'Khối 7. Tương tác và biểu mẫu',
  'Khối 8. Tài nguyên và đa phương tiện',
  'Khối 9. Điều hướng',
  'Khối 10. Hoạt ảnh',
  'Khối 11. Trợ năng và đa ngôn ngữ',
  'Khối 12. Quản lý trạng thái',
  'Khối 13. Dữ liệu và backend',
  'Khối 14. Kiến trúc ứng dụng',
  'Khối 15. Gói và plugin',
  'Khối 16. Kiểm thử và gỡ lỗi',
  'Khối 17. Hiệu năng',
  'Khối 18. Tích hợp nền tảng và mã gốc',
  'Khối 19. Triển khai',
  'Khối 20. AI trong Flutter',
];
const OPTIONS_PER_QUESTION = 4;

// ─── Màu terminal ──────────────────────────────────────────────────────────────
const C = {
  red: (s) => `\x1b[31m${s}\x1b[0m`,
  green: (s) => `\x1b[32m${s}\x1b[0m`,
  yellow: (s) => `\x1b[33m${s}\x1b[0m`,
  cyan: (s) => `\x1b[36m${s}\x1b[0m`,
  bold: (s) => `\x1b[1m${s}\x1b[0m`,
};

// ─── Load file ─────────────────────────────────────────────────────────────────
let raw;
try {
  raw = fs.readFileSync(QUESTIONS_PATH, 'utf8');
} catch (e) {
  console.error(C.red(`❌ Không đọc được file: ${QUESTIONS_PATH}`));
  console.error(e.message);
  process.exit(1);
}

let data;
try {
  data = JSON.parse(raw);
} catch (e) {
  console.error(C.red('❌ File JSON bị lỗi cú pháp:'), e.message);
  process.exit(1);
}

const questions = data.questions;
if (!Array.isArray(questions)) {
  console.error(C.red('❌ Thiếu trường "questions" hoặc không phải array.'));
  process.exit(1);
}

// ─── Validate từng câu ─────────────────────────────────────────────────────────
const errors = [];
const seenIds = new Set();
const categoryCount = {};
VALID_CATEGORIES.forEach((c) => (categoryCount[c] = 0));

for (let i = 0; i < questions.length; i++) {
  const q = questions[i];
  const prefix = `[Câu index ${i}${q?.id != null ? ` / id=${q.id}` : ''}]`;

  // id
  if (q.id == null || typeof q.id !== 'number' || !Number.isInteger(q.id)) {
    errors.push(`${prefix} Thiếu hoặc sai "id" (phải là số nguyên).`);
  } else {
    if (seenIds.has(q.id)) errors.push(`${prefix} id=${q.id} bị trùng.`);
    seenIds.add(q.id);
  }

  // category
  if (!VALID_CATEGORIES.includes(q.category)) {
    errors.push(`${prefix} category="${q.category}" không hợp lệ. Phải là: ${VALID_CATEGORIES.join(', ')}.`);
  } else {
    categoryCount[q.category]++;
  }

  // question
  if (!q.question || typeof q.question.vi !== 'string' || q.question.vi.trim() === '') {
    errors.push(`${prefix} Thiếu hoặc rỗng "question.vi".`);
  }
  if (!q.question || typeof q.question.en !== 'string' || q.question.en.trim() === '') {
    errors.push(`${prefix} Thiếu hoặc rỗng "question.en".`);
  }

  // options
  if (!Array.isArray(q.options)) {
    errors.push(`${prefix} "options" phải là array.`);
  } else {
    if (q.options.length !== OPTIONS_PER_QUESTION) {
      errors.push(`${prefix} Phải có đúng ${OPTIONS_PER_QUESTION} options, hiện có ${q.options.length}.`);
    }
    q.options.forEach((opt, oi) => {
      if (!opt || typeof opt.vi !== 'string' || opt.vi.trim() === '') {
        errors.push(`${prefix} options[${oi}].vi rỗng hoặc thiếu.`);
      }
      if (!opt || typeof opt.en !== 'string' || opt.en.trim() === '') {
        errors.push(`${prefix} options[${oi}].en rỗng hoặc thiếu.`);
      }
    });
  }

  // correctIndex
  const maxIdx = Array.isArray(q.options) ? q.options.length - 1 : OPTIONS_PER_QUESTION - 1;
  if (typeof q.correctIndex !== 'number' || !Number.isInteger(q.correctIndex) || q.correctIndex < 0 || q.correctIndex > maxIdx) {
    errors.push(`${prefix} correctIndex=${q.correctIndex} không hợp lệ (phải 0–${maxIdx}).`);
  }

  // explanation (tùy chọn ở version 2)
  if (q.explanation != null) {
    if (typeof q.explanation.vi !== 'string' || q.explanation.vi.trim() === '') {
      errors.push(`${prefix} Rỗng "explanation.vi".`);
    }
    if (typeof q.explanation.en !== 'string' || q.explanation.en.trim() === '') {
      errors.push(`${prefix} Rỗng "explanation.en".`);
    }
  }
}

// ─── Kiểm tra id tăng dần ──────────────────────────────────────────────────────
const sortedIds = [...seenIds].sort((a, b) => a - b);
if (sortedIds[0] !== 1) {
  errors.push(`id đầu tiên phải là 1, hiện là ${sortedIds[0]}.`);
}
for (let i = 1; i < sortedIds.length; i++) {
  if (sortedIds[i] !== sortedIds[i - 1] + 1) {
    errors.push(`id không liên tục: sau ${sortedIds[i - 1]} là ${sortedIds[i]} (thiếu ${sortedIds[i - 1] + 1}).`);
  }
}

// ─── Kết quả ──────────────────────────────────────────────────────────────────
console.log(C.bold('\n══════════════════════════════════════════'));
console.log(C.bold('  VALIDATE QUESTIONS.JSON'));
console.log(C.bold('══════════════════════════════════════════'));
console.log(`  File   : ${QUESTIONS_PATH}`);
console.log(`  Tổng   : ${questions.length} câu (yêu cầu: ${REQUIRED_TOTAL})`);
console.log('\n  Phân bổ theo category:');
VALID_CATEGORIES.forEach((cat) => {
  const count = categoryCount[cat];
  const bar = '█'.repeat(Math.round(count / 5));
  console.log(`    ${cat.padEnd(12)} ${String(count).padStart(3)} ${C.cyan(bar)}`);
});
console.log('');

if (questions.length !== REQUIRED_TOTAL) {
  errors.unshift(`Tổng số câu là ${questions.length}, cần đúng ${REQUIRED_TOTAL}.`);
}

if (errors.length > 0) {
  console.log(C.red(`❌ ${errors.length} lỗi tìm thấy:\n`));
  errors.slice(0, 30).forEach((e, i) => console.log(C.red(`  ${i + 1}. ${e}`)));
  if (errors.length > 30) console.log(C.yellow(`  ... và ${errors.length - 30} lỗi nữa.`));
  console.log('');
  process.exit(1);
} else {
  console.log(C.green(`✅ ${questions.length}/${REQUIRED_TOTAL} câu hợp lệ – sẵn sàng build!`));
  console.log('');
  process.exit(0);
}

