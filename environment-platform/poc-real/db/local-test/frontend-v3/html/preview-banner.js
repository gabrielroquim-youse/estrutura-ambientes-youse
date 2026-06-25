// Helper compartilhado: busca metadata do preview e gera sidebar.
window.preview = {
  _info: null,
  async load() {
    if (this._info) return this._info;
    const r = await fetch('/preview.json');
    const meta = await r.json();
    let orch = null;
    try {
      const r2 = await fetch('/api/preview-info');
      if (r2.ok) orch = await r2.json();
    } catch (e) { /* order-service indisponivel */ }
    this._info = { ...meta, ...(orch || {}) };
    return this._info;
  },
  sidebarHtml(info) {
    const title = info.preview_id === 'qa' ? 'QA compartilhado' : `Preview ${info.preview_id}`;
    const dbBadge = (info.db_source || '') === 'cloned'
      ? '<span class="preview">● clonado</span>'
      : '<span class="ok">● compartilhado</span>';
    const svc = (key, source, url) => {
      const cls = source === 'preview' ? 'preview' : 'skipped';
      const sym = source === 'preview' ? '● clonado' : '○ herdado QA';
      return `<div class="ts-line"><span>${key}</span><span class="${cls}" title="${url || ''}">${sym}</span></div>`;
    };
    const routing = info.routing || {};
    const own = info.preview_id === 'qa' ? 'compartilhado' : '● clonado';
    return `
      <div class="ts-title">▼ ${title}</div>
      <div class="ts-line"><span>Branch</span><span class="preview">${info.branch || '-'}</span></div>
      <div class="ts-line"><span>DB</span>${dbBadge}</div>
      <div class="ts-line"><span style="opacity:.6">DB name</span><span style="opacity:.7;font-size:10px">${info.db_name || ''}</span></div>
      <hr style="border:none;border-top:1px solid #374151;margin:8px 0">
      <div class="ts-line"><span>frontend</span><span class="preview">● clonado</span></div>
      <div class="ts-line"><span>order-service</span><span class="preview">● clonado</span></div>
      ${svc('pricing-engine', routing.pricing?.source, routing.pricing?.url)}
      ${svc('notification-svc', routing.notification?.source, routing.notification?.url)}
    `;
  },
};
