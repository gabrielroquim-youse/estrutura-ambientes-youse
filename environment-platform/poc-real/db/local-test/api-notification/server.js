// =============================================================================
// notification-service (mock) — envia email via SMTP
//
// Endpoints:
//   POST /send   envia email da cotacao
//   GET  /health
//
// Em producao Youse: envia via SES.
// Aqui: envia via Mailpit local (capturado em http://localhost:8025).
// =============================================================================
const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');

const app = express();
app.use(cors());
app.use(express.json());

const SERVICE_NAME = 'notification-service';
const PREVIEW_ID = process.env.PREVIEW_ID || 'qa';
const BRANCH = process.env.BRANCH_NAME || '(none)';

const SMTP = {
  host: process.env.SMTP_HOST || 'mailpit',
  port: parseInt(process.env.SMTP_PORT || '1025'),
  secure: false,
};
const SMTP_FROM = process.env.SMTP_FROM
  || `Youse Preview ${PREVIEW_ID} <noreply+${PREVIEW_ID}@preview.youse.test>`;

console.log(`[${SERVICE_NAME}] preview=${PREVIEW_ID} branch=${BRANCH}`);
console.log(`[${SERVICE_NAME}] SMTP -> ${SMTP.host}:${SMTP.port}, from=${SMTP_FROM}`);

const transporter = nodemailer.createTransport(SMTP);

function html({ name, quote_number, monthly, annual, vehicle, coverage_type, preview_id, branch }) {
  const previewBadge = preview_id === 'qa'
    ? '<div style="background:#10b981;color:#fff;padding:10px;text-align:center;font-size:13px"><strong>QA</strong> · ambiente compartilhado</div>'
    : `<div style="background:#ff6b35;color:#fff;padding:10px;text-align:center;font-size:13px"><strong>PREVIEW ${preview_id.toUpperCase()}</strong> · branch <code style="background:rgba(0,0,0,0.25);padding:2px 6px;border-radius:3px">${branch}</code></div>`;
  return `<!DOCTYPE html><html><body style="margin:0;font-family:-apple-system,'Segoe UI',sans-serif;background:#fafafa">
${previewBadge}
<div style="max-width:600px;margin:0 auto;padding:32px 24px">
  <h1 style="color:#1a1a2e;font-size:26px;margin:0 0 8px">you<span style="color:#ff6b35">se</span></h1>
  <p style="color:#6b7280;margin:0 0 24px;font-size:13px">Notificacao enviada por <strong>notification-service</strong> · preview <code>${preview_id}</code></p>
  <div style="background:#fff;border-radius:12px;padding:28px;border:1px solid #e5e7eb">
    <h2 style="margin:0 0 8px;color:#1a1a2e">Oi, ${name}!</h2>
    <p style="color:#374151;line-height:1.6">Sua cotacao <strong>${quote_number}</strong> esta pronta:</p>
    <div style="background:#fafafa;border-left:4px solid #ff6b35;padding:20px;margin:20px 0;border-radius:6px">
      <div style="font-size:13px;color:#6b7280;text-transform:uppercase">${coverage_type} · ${vehicle.brand} ${vehicle.model} ${vehicle.year}</div>
      <div style="font-size:36px;font-weight:800;color:#1a1a2e;margin:8px 0">
        R$ ${monthly.toFixed(2).replace('.',',')}<span style="font-size:16px;font-weight:400">/mes</span>
      </div>
      <div style="font-size:14px;color:#6b7280">ou R$ ${annual.toFixed(2).replace('.',',')} a vista</div>
    </div>
    <table style="width:100%;font-size:14px;color:#374151">
      <tr><td style="padding:6px 0;color:#6b7280">Placa</td><td style="text-align:right"><code>${vehicle.license_plate}</code></td></tr>
      <tr><td style="padding:6px 0;color:#6b7280">FIPE</td><td style="text-align:right">R$ ${vehicle.fipe_value.toFixed(2).replace('.',',')}</td></tr>
    </table>
  </div>
  <p style="color:#9ca3af;font-size:11px;text-align:center;margin-top:24px;line-height:1.6">
    Enviado de <strong>${preview_id === 'qa' ? 'QA compartilhado' : 'preview ' + preview_id}</strong>.<br>
    Outros previews/QA <strong>NAO recebem</strong> este email — isolamento total.
  </p>
</div></body></html>`;
}

app.get('/health', (_, res) => res.json({
  ok: true, service: SERVICE_NAME, preview: PREVIEW_ID, branch: BRANCH,
}));

app.post('/send', async (req, res) => {
  const { to, name, quote_number, monthly, annual, vehicle, coverage_type, preview_id, branch } = req.body;
  if (!to || !quote_number) return res.status(400).json({ error: 'to e quote_number obrigatorios' });

  // From dinamico: se o caller passou preview_id (diferente do nosso), usa ele.
  // Isso permite que um order-service de PR-456 chame o qa-notification compartilhado
  // e mesmo assim o email saia identificado como PR-456.
  const callerPreview = preview_id || PREVIEW_ID;
  const from = callerPreview === PREVIEW_ID
    ? SMTP_FROM
    : `Youse ${callerPreview.toUpperCase()} (via ${PREVIEW_ID}) <noreply+${callerPreview}@preview.youse.test>`;

  try {
    const info = await transporter.sendMail({
      from,
      to,
      subject: `[${callerPreview.toUpperCase()}] Sua cotacao Youse ${quote_number}`,
      html: html({ name, quote_number, monthly, annual, vehicle, coverage_type,
                   preview_id: callerPreview, branch: branch || BRANCH }),
      headers: {
        'X-Preview-Id': callerPreview,
        'X-Notification-Service-Preview': PREVIEW_ID,
      },
    });
    console.log(`[${SERVICE_NAME}] ✓ email -> ${to} (msgId=${info.messageId})`);
    res.json({
      status: 'sent',
      service: SERVICE_NAME,
      preview: PREVIEW_ID,
      to,
      message_id: info.messageId,
      sent_at: new Date().toISOString(),
    });
  } catch (e) {
    console.error(`[${SERVICE_NAME}] ✗ email falhou:`, e.message);
    res.status(500).json({ status: 'failed', error: e.message });
  }
});

const PORT = parseInt(process.env.PORT || '4000');
app.listen(PORT, () => console.log(`[${SERVICE_NAME}] ouvindo em :${PORT}`));
