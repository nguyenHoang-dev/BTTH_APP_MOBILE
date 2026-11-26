const app = require('./app');
const env = require('./config/env');

// 0.0.0.0 để điện thoại thật trong cùng mạng LAN truy cập được qua IP máy tính.
app.listen(env.port, '0.0.0.0', () => {
  console.log(`🚀 AI server chạy tại http://localhost:${env.port}`);
  console.log(
    env.isDemoMode
      ? '🧪 DEMO MODE: chưa có GEMINI_API_KEY -> trả dữ liệu giả lập'
      : `🤖 REAL MODE: dùng model ${env.geminiModel}`,
  );
});

