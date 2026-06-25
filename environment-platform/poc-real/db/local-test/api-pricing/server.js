// =============================================================================
// pricing-engine (mock) — calcula premio de seguro auto
//
// Endpoints:
//   POST /price   { fipe_value, year, coverage_type } -> { monthly, annual }
//   GET  /health
//
// Estatistico: este servico nao tem banco. So calcula.
// =============================================================================
const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const SERVICE_NAME = process.env.SERVICE_NAME || 'pricing-engine';
const PREVIEW_ID = process.env.PREVIEW_ID || 'qa';
const BRANCH = process.env.BRANCH_NAME || '(none)';

console.log(`[${SERVICE_NAME}] preview=${PREVIEW_ID} branch=${BRANCH}`);

app.get('/health', (_, res) => res.json({
  ok: true, service: SERVICE_NAME, preview: PREVIEW_ID, branch: BRANCH,
}));

app.post('/price', (req, res) => {
  const { fipe_value, year, coverage_type = 'completo' } = req.body;
  if (!fipe_value || !year) {
    return res.status(400).json({ error: 'fipe_value e year obrigatorios' });
  }
  const age = 2026 - year;
  const baseRate = coverage_type === 'basico' ? 0.018
                : coverage_type === 'completo' ? 0.035
                : 0.052;
  const ageFactor = 1 + (age * 0.02);
  const annual = fipe_value * baseRate * ageFactor;
  res.json({
    service: SERVICE_NAME,
    preview: PREVIEW_ID,
    monthly: Math.round(annual / 12 * 100) / 100,
    annual: Math.round(annual * 100) / 100,
    coverage_type,
    calculated_at: new Date().toISOString(),
  });
});

const PORT = parseInt(process.env.PORT || '4000');
app.listen(PORT, () => console.log(`[${SERVICE_NAME}] ouvindo em :${PORT}`));
