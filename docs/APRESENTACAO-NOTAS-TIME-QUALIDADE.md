# Notas do apresentador — Time de Qualidade (~40 min)

Use junto com [apresentacao-time-qualidade.md](./apresentacao-time-qualidade.md).

## Contexto

Este projeto **ainda está sendo montado**. Objetivo desta sessão: **validar com Qualidade**, não vender para liderança.

Sequência planejada:
1. **Qualidade** (agora) → co-criar golden-seed, validar fluxos
2. **Infra / DevOps** (depois) → viabilidade técnica e spike
3. **Liderança** (futuro) → quando proposta estiver madura

## Antes da reunião

- [ ] Enviar link do repo + doc v2 para QA lead 24h antes
- [ ] Confirmar: QA manual, QA automação, 1 analista por squad (se possível)
- [ ] Ter 1–2 exemplos reais de retrabalho por ambiente instável
- [ ] Exportar slides: VS Code + **Marp** → PDF

## Exportar slides (Marp)

1. Instalar extensão **Marp for VS Code**
2. Abrir `docs/apresentacao-time-qualidade.md`
3. `Ctrl+Shift+P` → **Marp: Export Slide Deck** → PDF ou PPTX

---

## Roteiro por slide

### Abertura (3 min)

**Slide Status** — Deixar claro: é rascunho, queremos **feedback**, não aprovação executiva.

**Slide Agenda** — Foco em impacto no dia a dia de QA, não em infra/custo.

### Problema (8 min)

**Slide O Problema** — Perguntar: *"Quantas vezes na última semana o QA estava instável quando vocês foram testar?"*

**Slide Evidências** — Mostrar que automação aponta para QA — conectar com flaky tests.

### Proposta (10 min)

**Slide Golden Template** — Enfatizar: **vocês definem a massa de dados**.

**Slide Fluxo Dev+QA** — Validar se operacionalmente funciona mover card + mesma URL.

**Slide Automação** — Ouvir objeções sobre migração de `qa-e2e-tests-automation`.

### O que muda (8 min)

**Slide Papéis** — Discussão: algum caso de uso hoje que não cabe nesse modelo?

**Slide Critérios de sucesso** — Perguntar se métricas fazem sentido para QA.

### Golden-seed (8 min)

**Slide Workshop** — **Principal entrega da reunião:** agendar workshop 2h.

**Slide Inventário** — QA automação pode listar top 10 specs/repos críticos.

### Fechamento (3 min)

**Slide Validação** — Coletar respostas às 5 perguntas na hora ou async.

**Slide Sequência** — Infra só depois do feedback de Qualidade.

---

## Objeções frequentes (time QA)

| Objeção | Resposta |
|---------|----------|
| "Dev não vai usar preview" | Piloto com 1 squad; mesma URL obrigatória para QA aceitar |
| "Massa de dados nunca é suficiente" | golden-seed versionado; QA dono do catálogo |
| "Automação vai quebrar na migração" | Fase separada; golden-automation com toggles fixos |
| "Produto ainda vai usar QA" | Regra + preview para UAT de feature |
| "Muito complexo" | Fase 0 = regras e calendário sem infra nova |

---

## Registro pós-reunião

1. Proposta faz sentido para QA? (sim / ajustes / não)
2. Fluxos para golden-seed v1: _______________
3. Squad piloto sugerido: _______________
4. Data workshop golden-seed: _______________
5. Ajustes na proposta: _______________
6. Pronto para apresentar Infra? (sim / não / depois de X)
