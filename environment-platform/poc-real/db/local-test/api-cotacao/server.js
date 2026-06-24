// =============================================================================
// server.js — API REST que simula pricing-engine + envio de email da Youse
//
// Endpoints:
//   POST /api/leads        → cria lead (nome + email + telefone)
//   POST /api/vehicles     → adiciona veiculo ao lead
//   POST /api/quotes       → calcula premio + envia email com a cotacao
//   GET  /api/quotes       → lista cotacoes do preview
//   GET  /api/health       → healthcheck
//
// SMTP:
//   Por padrao, envia via Mailpit local (mailpit:1025) que captura tudo
//   em http://localhost:8025 (UI tipo Gmail)
//
//   Para receber em e-mail REAL, configure no docker-compose:
//     SMTP_HOST: smtp.gmail.com         (ou smtp.resend.com)
//     SMTP_PORT: 587
//     SMTP_USER: seu-email@gmail.com
//     SMTP_PASS: <app-password>
//     SMTP_FROM: noreply@preview.youse.test
// =============================================================================

const express = require('express');
const cors = require('cors');
const { Client } = require('pg');
const nodemailer = require('nodemailer');

const app = express();
app.use(cors());
app.use(express.json());

// ----------------------------------------------------------------------------
// Config
// ----------------------------------------------------------------------------
const DB_CONFIG = {
    host: process.env.DB_HOST || 'postgres-qa-simulado',
    port: parseInt(process.env.DB_PORT || '5432'),
    user: process.env.DB_USER || 'youse',
    password: process.env.DB_PASSWORD || 'poc_local_only',
    database: process.env.DB_NAME || 'preview_you_123', // banco CLONADO
};

const SMTP_CONFIG = {
    host: process.env.SMTP_HOST || 'mailpit',
    port: parseInt(process.env.SMTP_PORT || '1025'),
    secure: process.env.SMTP_SECURE === 'true',
    auth: (process.env.SMTP_USER && process.env.SMTP_PASS) ? {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
    } : undefined,
};
const SMTP_FROM = process.env.SMTP_FROM || 'Youse Preview <noreply@preview.youse.test>';

console.log('▶ DB:  ', `${DB_CONFIG.user}@${DB_CONFIG.host}:${DB_CONFIG.port}/${DB_CONFIG.database}`);
console.log('▶ SMTP:', `${SMTP_CONFIG.host}:${SMTP_CONFIG.port}${SMTP_CONFIG.auth ? ' (auth)' : ' (no auth)'}`);

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------
async function db() {
    const client = new Client(DB_CONFIG);
    await client.connect();
    return client;
}

const transporter = nodemailer.createTransport(SMTP_CONFIG);

function calculatePremium(fipe, year, coverage) {
    const age = 2026 - year;
    const baseRate = coverage === 'basico' ? 0.018
                   : coverage === 'completo' ? 0.035
                   : 0.052;
    const ageFactor = 1 + (age * 0.02);
    const annual = fipe * baseRate * ageFactor;
    return {
        monthly: Math.round(annual / 12 * 100) / 100,
        annual:  Math.round(annual * 100) / 100,
    };
}

function quoteEmailHtml(name, quoteNumber, vehicle, premium, coverage) {
    const branch = process.env.BRANCH_NAME || 'feature/YOU-123-nova-cotacao';
    const previewDb = DB_CONFIG.database;
    return `
<!DOCTYPE html>
<html><head><meta charset="UTF-8"></head>
<body style="margin:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#fafafa;color:#1f2937">
  <div style="background:#ff6b35;color:#fff;padding:14px 24px;font-size:13px;text-align:center">
    <strong>PREVIEW</strong> · Email enviado do ambiente clonado <code style="background:rgba(0,0,0,0.25);padding:2px 6px;border-radius:3px">${branch}</code>
  </div>

  <div style="max-width:600px;margin:0 auto;padding:32px 24px">
    <h1 style="color:#1a1a2e;font-size:26px;margin:0 0 8px;letter-spacing:-0.5px">
      you<span style="color:#ff6b35">se</span>
    </h1>
    <p style="color:#6b7280;margin:0 0 24px;font-size:14px">Seguros online · Tipo vc</p>

    <div style="background:#fff;border-radius:12px;padding:28px;border:1px solid #e5e7eb">
      <h2 style="margin:0 0 8px;color:#1a1a2e">Oi, ${name}!</h2>
      <p style="color:#374151;line-height:1.6;margin:0 0 24px">
        Sua cotação <strong>${quoteNumber}</strong> ficou pronta. Olha só o resultado:
      </p>

      <div style="background:#fafafa;border-left:4px solid #ff6b35;padding:20px;margin-bottom:24px;border-radius:6px">
        <div style="font-size:13px;color:#6b7280;text-transform:uppercase;letter-spacing:0.5px">${coverage} · ${vehicle.brand} ${vehicle.model} ${vehicle.year}</div>
        <div style="font-size:36px;font-weight:800;color:#1a1a2e;margin:8px 0">
          R$ ${premium.monthly.toFixed(2).replace('.', ',')}<span style="font-size:16px;font-weight:400">/mês</span>
        </div>
        <div style="font-size:14px;color:#6b7280">ou R$ ${premium.annual.toFixed(2).replace('.', ',')} à vista</div>
      </div>

      <table style="width:100%;font-size:14px;color:#374151;border-collapse:collapse">
        <tr><td style="padding:8px 0;color:#6b7280">Placa</td><td style="padding:8px 0;text-align:right"><code>${vehicle.license_plate}</code></td></tr>
        <tr><td style="padding:8px 0;color:#6b7280">Veículo</td><td style="padding:8px 0;text-align:right">${vehicle.brand} ${vehicle.model}</td></tr>
        <tr><td style="padding:8px 0;color:#6b7280">Ano</td><td style="padding:8px 0;text-align:right">${vehicle.year}</td></tr>
        <tr><td style="padding:8px 0;color:#6b7280">FIPE</td><td style="padding:8px 0;text-align:right">R$ ${parseFloat(vehicle.fipe_value).toFixed(2).replace('.', ',')}</td></tr>
      </table>

      <div style="text-align:center;margin-top:28px">
        <a href="#" style="background:#ff6b35;color:#fff;text-decoration:none;padding:14px 32px;border-radius:8px;font-weight:700;display:inline-block">Contratar agora</a>
      </div>
    </div>

    <p style="color:#9ca3af;font-size:11px;text-align:center;margin-top:24px;line-height:1.6">
      Este e-mail veio do <strong>preview environment</strong> da branch <code>${branch}</code>,<br>
      usando o banco clonado <code>${previewDb}</code> (snapshot do QA).<br>
      qa.youse.io NÃO foi afetado.
    </p>
  </div>
</body></html>`;
}

// ----------------------------------------------------------------------------
// Routes
// ----------------------------------------------------------------------------
app.get('/api/health', async (_, res) => {
    try {
        const c = await db();
        await c.query('SELECT 1');
        await c.end();
        res.json({ ok: true, db: DB_CONFIG.database });
    } catch (e) {
        res.status(500).json({ ok: false, error: e.message });
    }
});

// Step 1: lead_info (nome + email + telefone)
app.post('/api/leads', async (req, res) => {
    const { name, email, phone, insurance_type = 'auto' } = req.body;
    if (!name || !email) return res.status(400).json({ error: 'name e email obrigatorios' });

    const c = await db();
    try {
        const uuid = `lead-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
        const r = await c.query(
            `INSERT INTO leads (lead_uuid, name, email, phone, insurance_type, source)
             VALUES ($1,$2,$3,$4,$5,'preview-flow')
             RETURNING *`,
            [uuid, name, email, phone || null, insurance_type]
        );
        res.status(201).json(r.rows[0]);
    } catch (e) {
        res.status(500).json({ error: e.message });
    } finally {
        await c.end();
    }
});

// Step 2: vehicle data
app.post('/api/vehicles', async (req, res) => {
    const { lead_id, license_plate, brand, model, year, fipe_value } = req.body;
    if (!lead_id) return res.status(400).json({ error: 'lead_id obrigatorio' });

    const c = await db();
    try {
        const r = await c.query(
            `INSERT INTO vehicles (lead_id, license_plate, brand, model, year, fipe_value)
             VALUES ($1,$2,$3,$4,$5,$6)
             RETURNING *`,
            [lead_id, license_plate, brand, model, year, fipe_value]
        );
        res.status(201).json(r.rows[0]);
    } catch (e) {
        res.status(500).json({ error: e.message });
    } finally {
        await c.end();
    }
});

// Step 3: gerar cotacao + enviar email
app.post('/api/quotes', async (req, res) => {
    const { lead_id, vehicle_id, coverage_type = 'completo' } = req.body;
    if (!lead_id || !vehicle_id) return res.status(400).json({ error: 'lead_id e vehicle_id obrigatorios' });

    const c = await db();
    try {
        // Buscar dados do lead e veiculo
        const leadR = await c.query('SELECT * FROM leads WHERE id = $1', [lead_id]);
        const vehR = await c.query('SELECT * FROM vehicles WHERE id = $1', [vehicle_id]);
        if (!leadR.rows[0] || !vehR.rows[0]) {
            return res.status(404).json({ error: 'lead ou veiculo nao encontrado' });
        }
        const lead = leadR.rows[0];
        const vehicle = vehR.rows[0];

        // Calcular premio
        const premium = calculatePremium(
            parseFloat(vehicle.fipe_value),
            vehicle.year,
            coverage_type
        );

        const quoteNumber = `YSE-PRV-${String(Date.now()).slice(-5)}`;

        // Salvar cotacao
        const r = await c.query(
            `INSERT INTO quotes
               (quote_number, lead_id, vehicle_id, coverage_type, monthly_premium, annual_premium, status)
             VALUES ($1,$2,$3,$4,$5,$6,'completed')
             RETURNING *`,
            [quoteNumber, lead_id, vehicle_id, coverage_type, premium.monthly, premium.annual]
        );
        const quote = r.rows[0];

        // Enviar email
        let emailStatus = 'skipped';
        let emailError = null;
        try {
            const info = await transporter.sendMail({
                from: SMTP_FROM,
                to: lead.email,
                subject: `Sua cotação Youse ${quoteNumber} — ${vehicle.brand} ${vehicle.model}`,
                html: quoteEmailHtml(lead.name, quoteNumber, vehicle, premium, coverage_type),
            });
            await c.query('UPDATE quotes SET email_sent_at = NOW() WHERE id = $1', [quote.id]);
            emailStatus = 'sent';
            console.log(`✓ Email enviado para ${lead.email}: ${info.messageId}`);
        } catch (e) {
            emailStatus = 'failed';
            emailError = e.message;
            console.error('✗ Erro ao enviar email:', e.message);
        }

        res.status(201).json({
            quote,
            lead,
            vehicle,
            premium,
            email: { status: emailStatus, to: lead.email, error: emailError },
        });
    } catch (e) {
        res.status(500).json({ error: e.message });
    } finally {
        await c.end();
    }
});

// Listar cotacoes
app.get('/api/quotes', async (_, res) => {
    const c = await db();
    try {
        const r = await c.query(`
            SELECT q.*,
                   l.name AS lead_name, l.email AS lead_email,
                   v.license_plate, v.brand, v.model, v.year
            FROM quotes q
            LEFT JOIN leads l    ON l.id = q.lead_id
            LEFT JOIN vehicles v ON v.id = q.vehicle_id
            ORDER BY q.id DESC
        `);
        res.json(r.rows);
    } catch (e) {
        res.status(500).json({ error: e.message });
    } finally {
        await c.end();
    }
});

const PORT = parseInt(process.env.PORT || '4000');
app.listen(PORT, () => {
    console.log(`▶ Cotacao API rodando em http://0.0.0.0:${PORT}`);
});
