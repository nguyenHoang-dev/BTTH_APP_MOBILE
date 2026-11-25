const express = require('express');
const cors = require('cors');
const explainRoutes = require('./routes/explain.routes');
const env = require('./config/env');
const { notFound, errorHandler } = require('./middlewares/error.middleware');

const app = express();

app.use(cors());
app.use(express.json({ limit: '50kb' }));

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', mode: env.isDemoMode ? 'demo' : 'real' });
});

// Rate limit: 20 req/phút/IP – đủ cho Practice Mode thực tế, chặn spam.
app.use('/api/explain', explainRoutes);

app.use(notFound);
app.use(errorHandler);

module.exports = app;

