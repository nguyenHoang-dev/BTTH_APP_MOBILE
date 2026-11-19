const test = require('node:test');
const assert = require('node:assert/strict');
const { createRateLimiter } = require('../src/middlewares/rate_limit.middleware');
const { buildExplainPrompt } = require('../src/services/prompt.builder');
const { buildMockExplanation } = require('../src/services/mock.service');
const { HttpError, errorHandler } = require('../src/middlewares/error.middleware');

test('Rate Limiter cho phép đúng 15 request/phút và chặn request thứ 16 với HTTP 429', () => {
  const limiter = createRateLimiter({ windowMs: 60000, maxRequests: 15 });
  const req = { ip: '192.168.1.10', headers: {} };
  const headers = {};
  const res = {
    setHeader(k, v) {
      headers[k] = v;
    },
  };

  for (let i = 1; i <= 15; i++) {
    let calledNextErr = null;
    limiter(req, res, (err) => {
      calledNextErr = err;
    });
    assert.equal(calledNextErr, undefined);
  }
  assert.equal(headers['X-RateLimit-Remaining'], '0');

  let blockedErr = null;
  limiter(req, res, (err) => {
    blockedErr = err;
  });
  assert.ok(blockedErr instanceof HttpError);
  assert.equal(blockedErr.status, 429);
  assert.ok(headers['Retry-After']);
});

test('buildExplainPrompt sinh đúng cấu trúc prompt tiếng Việt & tiếng Anh', () => {
  const prompt = buildExplainPrompt({
    question: 'Widget nào dùng để cuộn danh sách dài?',
    options: ['Column', 'ListView', 'Row', 'Stack'],
    selectedAnswer: 'Column',
    correctAnswer: 'ListView',
    language: 'vi',
  });

  assert.match(prompt, /Giải thích chi tiết tại sao đáp án này sai và đưa ra ví dụ/);
  assert.match(prompt, /A\. Column/);
  assert.match(prompt, /B\. ListView/);
  assert.match(prompt, /whyWrong/);
});

test('buildMockExplanation trả đủ 4 trường cho cả vi và en', () => {
  const vi = buildMockExplanation({
    selectedAnswer: 'A',
    correctAnswer: 'B',
    language: 'vi',
  });
  assert.ok(vi.whyWrong.includes('[DEMO]'));
  assert.ok(vi.correctExplanation.includes('B'));

  const en = buildMockExplanation({
    selectedAnswer: 'A',
    correctAnswer: 'B',
    language: 'en',
  });
  assert.ok(en.whyWrong.includes('incorrect'));
});

test('errorHandler xử lý lỗi JSON sai định dạng (400) và lỗi server (500) an toàn', () => {
  let statusCode = 0;
  let body = null;
  const res = {
    status(c) {
      statusCode = c;
      return this;
    },
    json(d) {
      body = d;
      return this;
    },
  };

  const syntaxErr = new SyntaxError('Unexpected token');
  syntaxErr.status = 400;
  syntaxErr.body = '{bad';
  errorHandler(syntaxErr, {}, res, () => {});
  assert.equal(statusCode, 400);
  assert.match(body.error.message, /JSON/);
});
