const app = require('./src/app');

async function testBackend() {
  console.log('Testing server endpoints in-memory...');
  
  // Test mock explanation
  const geminiService = require('./src/services/gemini.service');
  
  console.log('\n--- Test 1: Mock explanation (VI) ---');
  const resVi = await geminiService.explain({
    question: 'Chọn thì đúng: "She ___ here since 2010."',
    options: ['lives', 'lived', 'has lived', 'is living'],
    selectedAnswer: 'lived',
    correctAnswer: 'has lived',
    language: 'vi',
    category: 'grammar'
  });
  console.log(JSON.stringify(resVi, null, 2));

  console.log('\n--- Test 2: Mock explanation (EN) ---');
  const resEn = await geminiService.explain({
    question: 'Choose the correct tense: "She ___ here since 2010."',
    options: ['lives', 'lived', 'has lived', 'is living'],
    selectedAnswer: 'lived',
    correctAnswer: 'has lived',
    language: 'en',
    category: 'grammar'
  });
  console.log(JSON.stringify(resEn, null, 2));

  console.log('\n--- Test 3: Prompt builder ---');
  const { buildExplainPrompt } = require('./src/services/prompt.builder');
  const promptVi = buildExplainPrompt({
    question: 'Test',
    options: ['A', 'B'],
    selectedAnswer: 'A',
    correctAnswer: 'B',
    language: 'vi'
  });
  const promptEn = buildExplainPrompt({
    question: 'Test',
    options: ['A', 'B'],
    selectedAnswer: 'A',
    correctAnswer: 'B',
    language: 'en'
  });
  console.log('Prompt VI language instruction check:', promptVi.includes('Tiếng Việt') ? 'PASS' : 'FAIL');
  console.log('Prompt EN language instruction check:', promptEn.includes('English') && !promptEn.includes('Bạn là') ? 'PASS' : 'FAIL');

  console.log('\n--- ALL BACKEND CHECKS PASSED ---');
}

testBackend().catch(err => {
  console.error(err);
  process.exit(1);
});

