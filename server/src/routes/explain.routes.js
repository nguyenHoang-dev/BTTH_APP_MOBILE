const { Router } = require('express');
const { explainAnswer } = require('../controllers/explain.controller');

const router = Router();

// POST /api/explain
router.post('/', explainAnswer);

module.exports = router;

