const fs = require('fs');
const path = require('path');

const targetPath = 'E:/BTL_APP/BTTH_APP_MOBILE/mobile/assets/data/questions.json';
const scratchDir = 'E:/BTL_APP/BTTH_APP_MOBILE/brain/scratch';

const original = JSON.parse(fs.readFileSync(targetPath, 'utf8'));
const grammar = JSON.parse(fs.readFileSync(path.join(scratchDir, 'grammar_questions.json'), 'utf8'));
const vocabulary = JSON.parse(fs.readFileSync(path.join(scratchDir, 'vocabulary_questions.json'), 'utf8'));
const flutter = JSON.parse(fs.readFileSync(path.join(scratchDir, 'flutter_questions.json'), 'utf8'));
const networkDart = JSON.parse(fs.readFileSync(path.join(scratchDir, 'network_dart_questions.json'), 'utf8'));

const networkQ = networkDart.filter(q => q.category === 'network');
const dartQ = networkDart.filter(q => q.category === 'dart');

// 10 câu gốc:
// 3 grammar, 3 vocab, 3 flutter, 1 network
const q1_10 = original.questions.slice(0, 10);

// Thêm:
// 97 grammar (tổng 100)
// 77 vocab (tổng 80)
// 67 flutter (tổng 70)
// 29 network (tổng 30)
// 20 dart (tổng 20)
const combined = [
  ...q1_10,
  ...grammar.slice(0, 97),
  ...vocabulary.slice(0, 77),
  ...flutter.slice(0, 67),
  ...networkQ.slice(0, 29),
  ...dartQ.slice(0, 20)
];

// Re-index liên tục 1..300
combined.forEach((q, idx) => {
  q.id = idx + 1;
});

const finalData = {
  version: 1,
  description: "Ngân hàng 300 câu hỏi trắc nghiệm song ngữ Anh - Việt",
  questions: combined
};

fs.writeFileSync(targetPath, JSON.stringify(finalData, null, 2), 'utf8');
console.log(`Successfully merged and wrote ${combined.length} questions to ${targetPath}`);

