// =============================================================================
// order-service (mock) — BFF que orquestra cotacao
//
// Frontend chama SO este servico. Ele internamente:
//   1. Persiste lead/vehicle no DB (clonado)
//   2. Chama pricing-engine pra calcular premio
//   3. Persiste quote
//   4. Chama notification-service pra enviar email
//
// Endpoints:
//   POST /api/leads       cria lead
//   POST /api/vehicles    adiciona veiculo
//   POST /api/quotes      gera cotacao completa (orquestra tudo)
//   GET  /api/quotes
//   GET  /api/health
//   GET  /api/preview-info  metadata pro frontend exibir
// =============================================================================
const express = require('express');
const cors = require('cors');
const { Client } = require('pg');

const app = express();
app.use(cors());
app.use(express.json());

// ----------------------------------------------------------------------------
// Config — cada instancia recebe via env vars (DNS-only routing)
// ----------------------------------------------------------------------------
const SERVICE_NAME = 'order-service';
const PREVIEW_ID = process.env.PREVIEW_ID || 'qa';
const BRANCH = process.env.BRANCH_NAME || '(none)';
const CHANGED_SERVICES = (process.env.CHANGED_SERVICES || '').split(',').filter(Boolean);

const DB = {
  host: process.env.DB_HOST || 'postgres-qa-simulado',
  port: parseInt(process.env.DB_PORT || '5432'),
  user: process.env.DB_USER || 'youse',
  password: process.env.DB_PASSWORD || 'poc_local_only',
  database: process.env.DB_NAME || 'monolithic_qa',
};

// URLs dos servicos colaterais (apontam pro preview OU pro QA herdado)
const PRICING_URL = process.env.PRICING_URL || 'http://pricing-engine.qa:4000';
const NOTIFICATION_URL = process.env.NOTIFICATION_URL || 'http://notification-service.qa:4000';

console.log(`[${SERVICE_NAME}] preview=${PREVIEW_ID} branch=${BRANCH}`);
console.log(`[${SERVICE_NAME}] DB: ${DB.user}@${DB.host}/${DB.database}`);
console.log(`[${SERVICE_NAME}] pricing -> ${PRICING_URL}`);
console.log(`[${SERVICE_NAME}] notification -> ${NOTIFICATION_URL}`);
console.log(`[${SERVICE_NAME}] changed services: [${CHANGED_SERVICES.join(', ') || 'none'}]`);

async function db() {
  const c = new Client(DB);
  await c.connect();
  return c;
}

// ----------------------------------------------------------------------------
// Routes
// ----------------------------------------------------------------------------
app.get('/api/health', async (_, res) => {
  try {
    const c = await db(); await c.query('SELECT 1'); await c.end();
    res.json({ ok: true, service: SERVICE_NAME, preview: PREVIEW_ID, db: DB.database });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

app.get('/api/preview-info', (_, res) => {
  res.json({
    preview_id: PREVIEW_ID,
    branch: BRANCH,
    db_name: DB.database,
    changed_services: CHANGED_SERVICES,
    routing: {
      pricing: { url: PRICING_URL, source: isPreview(PRICING_URL) ? 'preview' : 'inherited-from-qa' },
      notification: { url: NOTIFICATION_URL, source: isPreview(NOTIFICATION_URL) ? 'preview' : 'inherited-from-qa' },
    },
    db_source: DB.database.startsWith('preview_') ? 'cloned' : 'inherited-from-qa',
  });
});

// Considera "preview" se a URL contiver o ID do preview normalizado (ex: pr123)
// na parte do hostname. Caso contrario, e um servico herdado (compartilhado QA).
function isPreview(url) {
  if (PREVIEW_ID === 'qa') return true;
  const normalized = PREVIEW_ID.replace(/-/g, '');
  // hostname tipico: pr123-pricing, pr456-order, qa-notification
  return new RegExp(`(^|//)${normalized}-`).test(url);
}

app.post('/api/leads', async (req, res) => {
  const { name, email, phone } = req.body;
  if (!name || !email) return res.status(400).json({ error: 'name e email obrigatorios' });
  const c = await db();
  try {
    const uuid = `lead-${PREVIEW_ID}-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
    const r = await c.query(
      `INSERT INTO leads (lead_uuid, name, email, phone, insurance_type, source)
       VALUES ($1,$2,$3,$4,'auto',$5) RETURNING *`,
      [uuid, name, email, phone || null, `preview-${PREVIEW_ID}`]
    );
    res.status(201).json(r.rows[0]);
  } catch (e) { res.status(500).json({ error: e.message }); }
  finally { await c.end(); }
});

app.post('/api/vehicles', async (req, res) => {
  const { lead_id, license_plate, brand, model, year, fipe_value } = req.body;
  if (!lead_id) return res.status(400).json({ error: 'lead_id obrigatorio' });
  const c = await db();
  try {
    const r = await c.query(
      `INSERT INTO vehicles (lead_id, license_plate, brand, model, year, fipe_value)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [lead_id, license_plate, brand, model, year, fipe_value]
    );
    res.status(201).json(r.rows[0]);
  } catch (e) { res.status(500).json({ error: e.message }); }
  finally { await c.end(); }
});

// Quote = orquestra tudo
app.post('/api/quotes', async (req, res) => {
  const { lead_id, vehicle_id, coverage_type = 'completo' } = req.body;
  if (!lead_id || !vehicle_id) return res.status(400).json({ error: 'lead_id e vehicle_id obrigatorios' });

  const c = await db();
  try {
    const leadR = await c.query('SELECT * FROM leads WHERE id = $1', [lead_id]);
    const vehR = await c.query('SELECT * FROM vehicles WHERE id = $1', [vehicle_id]);
    if (!leadR.rows[0] || !vehR.rows[0]) {
      return res.status(404).json({ error: 'lead ou veiculo nao encontrado' });
    }
    const lead = leadR.rows[0];
    const vehicle = vehR.rows[0];

    // 1) Chamar pricing-engine (preview OU qa)
    let pricing;
    try {
      const pr = await fetch(`${PRICING_URL}/price`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          fipe_value: parseFloat(vehicle.fipe_value),
          year: vehicle.year,
          coverage_type,
        }),
      });
      pricing = await pr.json();
      if (!pr.ok) throw new Error(pricing.error || `pricing returned ${pr.status}`);
    } catch (e) {
      return res.status(502).json({ error: `pricing-engine falhou: ${e.message}`, pricing_url: PRICING_URL });
    }

    // 2) Salvar quote
    const quoteNumber = `YSE-${PREVIEW_ID.toUpperCase()}-${String(Date.now()).slice(-5)}`;
    const r = await c.query(
      `INSERT INTO quotes (quote_number, lead_id, vehicle_id, coverage_type, monthly_premium, annual_premium, status)
       VALUES ($1,$2,$3,$4,$5,$6,'completed') RETURNING *`,
      [quoteNumber, lead_id, vehicle_id, coverage_type, pricing.monthly, pricing.annual]
    );
    const quote = r.rows[0];

    // 3) Disparar notification (preview OU qa)
    let notification = { status: 'skipped' };
    try {
      const nr = await fetch(`${NOTIFICATION_URL}/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          to: lead.email,
          name: lead.name,
          quote_number: quoteNumber,
          monthly: pricing.monthly,
          annual: pricing.annual,
          vehicle: { brand: vehicle.brand, model: vehicle.model, year: vehicle.year,
                     license_plate: vehicle.license_plate, fipe_value: parseFloat(vehicle.fipe_value) },
          coverage_type,
          preview_id: PREVIEW_ID,
          branch: BRANCH,
        }),
      });
      notification = await nr.json();
      if (nr.ok) {
        await c.query('UPDATE quotes SET email_sent_at = NOW() WHERE id = $1', [quote.id]);
      }
    } catch (e) {
      notification = { status: 'failed', error: e.message };
    }

    res.status(201).json({
      quote, lead, vehicle, pricing, notification,
      orchestration: {
        order_service: { preview: PREVIEW_ID, source: 'preview' },
        pricing_engine: { url: PRICING_URL, source: isPreview(PRICING_URL) ? 'preview' : 'inherited-from-qa' },
        notification_service: { url: NOTIFICATION_URL, source: isPreview(NOTIFICATION_URL) ? 'preview' : 'inherited-from-qa' },
        db: DB.database,
      },
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  } finally { await c.end(); }
});

app.get('/api/quotes', async (_, res) => {
  const c = await db();
  try {
    const r = await c.query(`
      SELECT q.*, l.name AS lead_name, l.email AS lead_email,
             v.brand, v.model, v.year, v.license_plate
      FROM quotes q
      LEFT JOIN leads l ON l.id = q.lead_id
      LEFT JOIN vehicles v ON v.id = q.vehicle_id
      ORDER BY q.id DESC LIMIT 20
    `);
    res.json(r.rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
  finally { await c.end(); }
});

const PORT = parseInt(process.env.PORT || '4000');
app.listen(PORT, () => console.log(`[${SERVICE_NAME}] ouvindo em :${PORT}`));
