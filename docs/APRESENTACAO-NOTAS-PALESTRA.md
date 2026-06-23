# Notas do apresentador — CTO (~45 min)

Use junto com [apresentacao-cto.md](./apresentacao-cto.md).

## Antes da reunião

- [ ] Enviar PDF v1.3 + link do repo 24h antes
- [ ] Confirmar presença: DevOps/Plataforma, 1 EM de squad, QA lead
- [ ] Ter exemplo real de msg Slack "parem de usar QA" (anonimizado)
- [ ] Exportar slides: VS Code + extensão **Marp** → PDF ou PPT

## Exportar slides (Marp)

1. Instalar extensão **Marp for VS Code**
2. Abrir `docs/apresentacao-cto.md`
3. `Ctrl+Shift+P` → **Marp: Export Slide Deck** → PDF ou PPTX

---

## Roteiro por slide

### Abertura (5 min)

**Slide Agenda** — Deixar claro: não é só infra, é produtividade e previsibilidade de release.

**Slide O Problema** — Perguntar: *"Quantos aqui já perderam tempo porque QA estava instável?"* Deixar o CTO reconhecer o problema antes dos números.

### Evidências (8 min)

**Slide Evidências** — Destacar ratio 6,8:1. O handbook existe; o gap é operacional.

**Slide Custo oculto** — Se questionarem números: são estimativas conservadoras; validar com EM na Fase 0.

### Proposta (12 min)

**Slide Duas camadas** — Enfatizar: preview **não substitui** esteira de release.

**Slide Golden Template** — Analogia: *"foto do ambiente ideal com dados prontos — cada branch tira uma cópia"*.

**Slide Fluxo Dev+QA** — Caso de uso YOU-123. QA na mesma URL = fim do "funcionou no meu ambiente".

**Slide Automação efêmera** — Diferenciar de `auto.youse.io` fixo (regressão estável).

### Arquitetura (8 min)

**Slide Mapa** — QA compartilhado vira só RC; uso diário vai para preview.

**Slide Pipeline release** — Gates G1–G5; deploy manual proibido em QA/Automation/Pre-Prod.

### Viabilidade (5 min)

**Slide Já temos** — Mensagem: *"não estamos propondo trocar tudo — estamos organizando o que existe"*.

**Slide Construir** — Control plane pode começar como scripts no `deployment-orb` (Fase 0–1).

### Piloto e ROI (5 min)

**Slide Piloto** — Pedir input ao CTO: qual squad/repo faz mais sentido?

**Slide Decisões** — Parar aqui. Obter sim/não nas 5 decisões.

### Fechamento (2 min)

**Slide Próximas 2 semanas** — Só apresentar se houver aprovação in-principle.

---

## Objeções frequentes

| Objeção | Resposta |
|---------|----------|
| "Muitos ambientes = caro" | L1 híbrido no piloto; TTL + destroy; custo < retrabalho |
| "461 repos é complexo demais" | Opt-in por repo; piloto com 1; catálogo por domínio |
| "Golden fica desatualizado" | Refresh diário; alerta se Stage > 24h à frente |
| "Clone de DB é lento" | L1 usa seed script; snapshot RDS só para automation |
| "Time não vai adotar" | Quick wins Fase 1 (calendário, regras) sem infra nova |

---

## Decisões a registrar na ata

1. Estratégia v2 aprovada? (sim / sim com ressalvas / não)
2. Squad piloto: _______________
3. Repo piloto: _______________
4. Owner Plataforma: _______________
5. Data workshop golden-seed: _______________
