const { Router } = require('express');
const { explainAnswer } = require('../controllers/explain.controller');
const { aiRateLimiter } = require('../middlewares/rate_limit.middleware');

const router = Router();

// POST /api/explain (giới hạn tối đa 15 lượt gọi / phút / IP)
router.post('/', aiRateLimiter, explainAnswer);

module.exports = router;


