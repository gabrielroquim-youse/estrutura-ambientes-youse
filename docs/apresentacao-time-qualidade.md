---
marp: true
theme: default
paginate: true
header: "Projeto Ambientes Youse | Junho 2026"
footer: "Em construção — rascunho interno"
style: |
  section {
    font-size: 28px;
  }
  section.lead h1 {
    font-size: 2.2em;
  }
  section.small {
    font-size: 22px;
  }
  table {
    font-size: 0.75em;
  }
  blockquote {
    border-left: 4px solid #0066cc;
    padding-left: 1em;
    color: #333;
  }
---

<!-- _class: lead -->

# Projeto Ambientes Youse
## Ambientes por Clone — Golden Template

**Validação com Time de Qualidade** · Fase 1

Gabriel Roquim · Junho/2026 · v2.0 (rascunho)

Repo: github.com/gabrielroquim-youse/estrutura-ambientes-youse

---

## Status do projeto

> **Em construção** — documentação e proposta sendo montadas.

| Fase | Público | Status |
|------|---------|--------|
| **1** | Time de Qualidade | **Agora** — co-criar e validar |
| **2** | Time de Infra / DevOps | Depois — viabilidade técnica |
| **3** | Liderança | Futuro — após alinhamento dos times |

---

## Agenda (~40 min)

1. O problema de hoje — impacto no dia a dia de QA
2. A proposta — ambientes por clone
3. Fluxos Dev + QA + Automação
4. O que muda para Qualidade
5. **Massa de dados e golden-seed** — input do time
6. Próximos passos juntos

---

<!-- _class: lead -->

# 1. O Problema

---

## Todo mundo testa no mesmo lugar

**Hoje:** `qa.youse.io` é usado por dev, QA, produto e automação — ao mesmo tempo.

Situações que o time de Qualidade vive todo dia:

- QA vai testar e o ambiente está quebrado
- Slack: *"parem de usar QA, vou mexer no ambiente"*
- Automação falha sem mudança de código
- Não dá para garantir o que foi testado vs. o que vai para prod
- Re-testes frequentes — *"funcionou ontem, hoje quebrou"*

> **Não é culpa de QA.** É falta de ambiente dedicado por tarefa.

---

## Evidências — auditoria GitHub

Auditoria na org **youse-seguradora** · 461 repositórios · Jun/2026

| Fato | Impacto em QA |
|------|---------------|
| **313 refs** a `qa.youse.io` | QA compartilhado com dev, produto e robôs |
| **0 refs** a `auto.youse.io` | E2E roda no mesmo QA instável |
| Ratio QA:Stage **6,8:1** | QA absorve papéis que deveriam ser separados |
| `qa-e2e-tests-automation` → QA | Falsos positivos quando ambiente muda |

Handbook define papéis diferentes — **a prática divergiu**.

---

<!-- _class: lead -->

# 2. A Proposta

---

## Uma frase

**Cada tarefa ganha um ambiente próprio — clonado de um padrão com massa de dados — que some quando a tarefa termina.**

QA compartilhado (`qa.youse.io`) passa a receber **só release candidate** — não feature em andamento.

---

## Duas camadas que trabalham juntas

| Camada | Nome | Para quê? |
|--------|------|-----------|
| **1** | Ambientes fixos | Release, regressão, UAT de RC, pré-prod |
| **2** | Clone por branch | Dev + QA testam a **mesma URL** por tarefa |

```
DURANTE A TAREFA          APÓS MERGE (release)
────────────────          ────────────────────
Dev + QA no preview  →    Stage → Automation → QA/UAT → Pre-Prod → Prod
       ↓
  Destruído ao fechar
```

---

## Golden Template — o coração

Ambiente padrão com versões, toggles e **massa de dados conhecida**.

| Template | Massa de dados | Uso |
|----------|----------------|-----|
| `golden-qa` | Seed UAT (apólices, CPFs, fluxos) | Dev + QA + Produto por branch |
| `golden-automation` | Seed E2E congelado + toggles fixos | Automação estável e efêmera |

**Precisamos do time de Qualidade** para definir o conteúdo do `golden-seed` v1.

---

## Fluxo Dev + QA (dia a dia)

```
1. Dev abre branch feature/YOU-123
2. Clone golden-qa → you-123.preview.youse.io
3. Dev testa no preview (não no QA compartilhado)
4. Dev avisa QA → QA testa na MESMA URL
5. Aprovado → merge → segue esteira de release
6. Preview destruído (merge ou TTL 72h)
```

**Regra de ouro:** QA usa a **mesma URL** do dev — fim do *"no meu ambiente funciona"*.

---

## Automação — o que muda para QA

| Hoje | Depois |
|------|--------|
| E2E roda em QA compartilhado | Regressão estável em `auto.youse.io` |
| Toggles alterados manualmente | Toggles congelados no golden-automation |
| Falsos positivos frequentes | Ambiente imutável entre runs |
| PR sem ambiente isolado | YAML → clone → teste → destroy |

Repos afetados: `qa-e2e-tests-automation`, `platform-automated-testing`

---

<!-- _class: lead -->

# 3. O que muda para Qualidade

---

## Papéis — antes e depois

| Atividade | Hoje | Depois |
|-----------|------|--------|
| Teste de feature em andamento | QA compartilhado | Preview da branch |
| Teste de release candidate | QA (misturado) | QA/UAT (só RC promovido) |
| Regressão E2E | QA instável | `auto.youse.io` dedicado |
| UAT Produto | QA enquanto dev deploya | Preview ou RC estável |

---

## Mapa de ambientes (visão QA)

| Ambiente | QA usa para... | Efêmero? |
|----------|----------------|----------|
| Preview branch | Tarefa em andamento | ✅ Sim |
| QA / UAT | Release candidate | Não |
| Automation | Validar promote (E2E) | Não |
| Stage | Integração pós-merge (smoke) | Não |

Perf/Chaos → ambiente dedicado `perf.youse.io` (fora do escopo desta fase)

---

## Critérios de sucesso — perspectiva QA

1. Teste de tarefa **sempre** no preview — não no QA compartilhado
2. QA/UAT recebe **apenas RC** promovido por pipeline
3. Automação flaky **< 5%** em ambiente dedicado
4. Massa de dados **previsível** em todo clone
5. Fim das msgs *"parem de usar QA"* no dia a dia

---

<!-- _class: lead -->

# 4. Golden-seed — precisamos de vocês

---

## Workshop: massa de dados v1

O clone só funciona se a **massa de dados** for útil para QA.

| Item | Exemplo | Quem define |
|------|---------|-------------|
| Usuários / CPFs de teste | Contas Auto, login app | QA |
| Apólices / cotações | Fluxos felizes e edge cases | QA |
| Feature flags baseline | ON/OFF por fluxo | QA + Automação |
| Dados por produto | Auto, Residencial, etc. | QA por squad |
| Contas proibidas | Dados que não podem ser resetados | QA |

Entregável: catálogo v1 → vira `golden-seed/` no repo

---

## Inventário refs QA (313)

Precisamos classificar o que aponta para `qa.youse.io` hoje:

| Tipo | Ação sugerida |
|------|---------------|
| Specs de teste manual | Migrar para URL dinâmica (preview) |
| Config automação E2E | Migrar para `auto.youse.io` |
| `.env` / configs dev | Manter ou apontar preview |
| Documentação | Atualizar handbook |

**QA pode ajudar** priorizando repos de automação e specs críticos.

---

<!-- _class: lead -->

# 5. Próximos passos

---

## O que validamos com Qualidade hoje

| # | Pergunta para o time |
|---|---------------------|
| 1 | A proposta resolve as dores reais do dia a dia? |
| 2 | O fluxo *dev + QA na mesma URL* faz sentido operacionalmente? |
| 3 | Quais fluxos entram no **golden-seed v1**? |
| 4 | Qual squad/repo seria bom **piloto**? |
| 5 | O que está faltando ou sobrando nesta proposta? |

---

## Sequência do projeto

```
Agora          Próximo              Depois
────────       ───────────────      ──────────────
Validação  →   Apresentação     →   Liderança
Qualidade      Infra / DevOps       (quando maduro)
     │                │
     └─ golden-seed v1 ─┴─ spike técnico (POC)
```

---

## Próximas ações (com Qualidade)

| Ação | Prazo sugerido |
|------|----------------|
| Workshop golden-seed v1 (2h) | Semana 1 |
| Listar contas/dados de teste atuais | Semana 1 |
| Priorizar repos de automação para migrar | Semana 2 |
| Feedback escrito nesta proposta | Semana 2 |
| Preparar versão para Infra | Após feedback QA |

---

<!-- _class: lead -->

# Obrigado

## Perguntas e feedback?

**Documentação:**
- `PROJETO-AMBIENTES-YOUSE-v2-CLONE.md`
- `PROJETO-AMBIENTES-YOUSE.pdf` (v1.3 + auditoria)

**Repositório:** github.com/gabrielroquim-youse/estrutura-ambientes-youse

---

<!-- _class: small -->

## Anexo — cartilha QA (resumo)

**Faça:** teste de tarefa no preview · RC em QA/UAT · reporte com hash de versão

**Não faça:** alterar dados globais sem aviso · ignorar pipeline E2E vermelho · E2E no QA compartilhado

**Automação:** toggles congelados em `auto.youse.io` · seed versionado · teardown em runs efêmeros
