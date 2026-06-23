---
marp: true
theme: default
paginate: true
header: "Projeto Ambientes Youse | Junho 2026"
footer: "Confidencial — Youse Seguradora"
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

**Proposta para CTO e Liderança Técnica**

Gabriel Roquim · Junho/2026 · v2.0

Repo: github.com/gabrielroquim-youse/estrutura-ambientes-youse

---

## Agenda (~45 min)

1. O problema de hoje — com evidências
2. A proposta — ambientes por clone
3. Arquitetura e fluxos (Dev, QA, Automação)
4. O que já temos vs. o que falta
5. Piloto, roadmap e investimento
6. **Decisões que precisamos**

---

<!-- _class: lead -->

# 1. O Problema

---

## Todo mundo testa no mesmo lugar

**Hoje:** `qa.youse.io` é usado por dev, QA, produto e automação — ao mesmo tempo.

Situações que o time vive todo dia:

- QA vai testar e o ambiente está quebrado
- Slack: *"parem de usar QA, vou mexer no ambiente"*
- Automação falha sem mudança de código
- Performance/caos no Stage deixa integração lenta
- Ninguém sabe o que está rodando em QA agora

> **Não é culpa de um time.** É falta de regra clara sobre *onde* cada atividade deve acontecer.

---

## Evidências — auditoria GitHub

Auditoria na org **youse-seguradora** · 461 repositórios · Jun/2026

| Fato | Significado |
|------|-------------|
| **313 refs** a `qa.youse.io` | QA virou ambiente padrão de tudo |
| **46 refs** a Stage | Stage subutilizado para o volume de QA |
| **0 refs** a `auto.youse.io` | Automação sem ambiente dedicado |
| **0 refs** a `perf.youse.io` | Carga/caos no Stage e QA |
| Ratio QA:Stage **6,8:1** | Concentração crítica em um ambiente |

Handbook define papéis diferentes — **a prática divergiu**.

---

## Custo oculto (estimativa)

| Impacto | Baseline |
|---------|----------|
| Horas/semana perdidas com ambiente instável | **15–25h** (time combinado) |
| Taxa de falso positivo na automação | Alta — pipeline vermelho ignorado |
| Re-testes por release | Frequentes |
| Mensagens "parem de usar QA" | Semanal |
| Releases | Atrasadas por falta de janela estável |

> Custo de 2–3 ambientes adicionais **<** custo oculto de retrabalho e releases atrasados.

---

<!-- _class: lead -->

# 2. A Proposta

---

## Uma frase

**Cada tarefa ganha um ambiente próprio — clonado de um padrão com massa de dados — que some quando a tarefa termina.**

Ambientes fixos continuam existindo para **release até produção**.

---

## Duas camadas que trabalham juntas

| Camada | Nome | Analogia | Para quê? |
|--------|------|----------|-----------|
| **1** | Ambientes fixos | Salas permanentes do prédio | Release, regressão, UAT, pré-prod |
| **2** | Clone por branch | Mesa montada só para aquela entrega | Dev + QA + Produto no dia a dia |

```
DURANTE A TAREFA          APÓS MERGE (release)
────────────────          ────────────────────
Dev + QA no preview  →    Stage → Automation → QA/UAT → Pre-Prod → Prod
(ambiente temporário)       (ambientes fixos)
       ↓
  Destruído ao fechar
```

---

## Golden Template — o coração

Ambiente **fixo**, atualizado diariamente, com versões, toggles e **massa de dados conhecida**.

| Template | Massa de dados | Quem clona |
|----------|----------------|------------|
| `golden-dev` | Seed mínimo (smoke) | Dev em features simples |
| `golden-qa` | Seed UAT (apólices, CPFs, fluxos) | Dev + QA + Produto |
| `golden-automation` | Seed E2E congelado + toggles fixos | Pipeline de automação |

**Clone ≠ deploy vazio.** Clone = infra + config + dados do template.

---

## Fluxo Dev + QA (dia a dia)

```
1. Dev abre branch feature/YOU-123
2. Sistema clona golden-qa → you-123.preview.youse.io
3. Dev desenvolve e testa NO PREVIEW (não no QA compartilhado)
4. Dev avisa QA → QA testa na MESMA URL
5. Aprovado → merge → Stage → ... → Produção
6. Preview destruído automaticamente (merge ou TTL 72h)
```

**Regra de ouro:** QA nunca cria clone separado — usa a mesma URL do dev.

---

## Automação efêmera (YAML → teste → destroy)

Para E2E de PR, reprodução de bug ou suite sob demanda:

```
1. Pipeline lê YAML de ambiente
2. Clona golden-automation
3. Roda suite (Playwright)
4. DESTROY — sempre (sucesso ou falha)
```

Ambiente fixo `auto.youse.io` **continua** para regressão estável pós-Stage.

---

<!-- _class: lead -->

# 3. Arquitetura

---

## Mapa completo de ambientes

| Ambiente | Tipo | URL | Efêmero? |
|----------|------|-----|----------|
| Preview branch | Clone | `*.preview.youse.io` | ✅ Sim |
| Auto ephemeral | Clone | `*.auto-preview.youse.io` | ✅ Sim |
| Stage | Release | `www-stage.youse.io` | Não |
| Automation | Release | `auto.youse.io` | Não |
| QA / UAT | Release | `qa.youse.io` | Não |
| Pre-Prod | Release | `preprod.youse.io` | Não |
| Perf / Chaos | Especializado | `perf.youse.io` | Não |
| Produção | Release | `www.youse.io` | Não |

---

## O que compõe um clone

```
Clone = Namespace Kubernetes
      + Serviços (template ± overlay da branch)
      + Banco clonado ou seed idempotente
      + Feature flags (snapshot)
      + DNS + TLS
      + Integrações → sandbox (nunca prod)
      + Massa de dados versionada
```

Evolução em 3 níveis: **L1 híbrido** (piloto) → **L2 domínio** → **L3 full-stack**

---

## Pipeline de release (pós-merge)

```
Merge main
  → Stage          (integração — gate G1)
  → Automation     (E2E estável — gate G2, ≥98%)
  → QA / UAT       (RC — gate G3, QA + Produto)
  → Pre-Prod       (smoke + security — gate G4)
  → Produção       (gate G5, release manager)
```

Preview **nunca substitui** Pre-Prod.

---

<!-- _class: lead -->

# 4. Viabilidade Técnica

---

## O que a Youse **já tem**

| Peça | Repo / ferramenta |
|------|-------------------|
| Kubernetes + namespaces | `gitops-kubernetes-addons` |
| Deploy por serviço | Helm (`.helm/qa.yaml`, `.helm/stage.yaml`) |
| CI/CD | CircleCI + `deployment-orb` (~159 repos) |
| IaC | `terraform`, `terraform-platform` |
| Automação E2E moderna | `qa-e2e-tests-automation` (Playwright + GHA) |

**Conclusão: é possível.** Falta montar a camada de clone — não reinventar infra.

---

## O que **precisamos construir**

1. **Golden Templates** — 3 ambientes padrão com refresh diário
2. **`golden-seed`** — massa de dados versionada e idempotente
3. **Control Plane** — create/destroy (pipeline → Operator K8s)
4. **DNS wildcard** — `*.preview.youse.io`
5. **Governança** — TTL, quotas, destroy de órfãos
6. **Extensão `deployment-orb`** — jobs clone + destroy

Repo proposto na org: **`youse-seguradora/environment-platform`**

---

<!-- _class: lead -->

# 5. Piloto e Roadmap

---

## Piloto sugerido (30 dias)

| Item | Escolha |
|------|---------|
| Squad | 1 squad (ex.: Auto) |
| Repositório | `sales-frontend` (ou serviço com deploy frequente em QA) |
| Modelo | Clone **L1** — híbrido + seed do golden |
| Métricas | Conflitos no QA, tempo de espera QA, msgs Slack |

**Entregável:** push em `feature/YOU-123` → URL exclusiva → dev + QA → merge → destroy

---

## Roadmap — 120 dias

| Fase | Semanas | Entrega principal |
|------|---------|-------------------|
| **0 — Fundação** | 1–3 | Aprovação, golden-seed v1, inventário refs QA |
| **1 — Golden** | 4–6 | `golden-dev` + `golden-qa`, DNS wildcard |
| **2 — Piloto L1** | 7–10 | 1 repo + `deployment-orb` clone/destroy |
| **3 — Automação** | 11–14 | YAML efêmero + `golden-automation` |
| **4 — Escala** | 15–18 | Top 10 repos, `perf.youse.io`, Pre-Prod |

Fase 1 do doc v1.3 (regras + calendário) pode começar **sem infra nova**.

---

<!-- _class: small -->

## Investimento estimado

| Item | Esforço | Custo infra |
|------|---------|-------------|
| Golden Templates + Control Plane | 2–3 sprints | Namespaces sob demanda |
| Ambiente Automation fixo | 2–3 sprints | 30–50% de Stage |
| Ambiente Perf/Chaos | 1–2 sprints | 40–60% (spot) |
| Pre-Prod | 2 sprints | 50–70% prod reduzido |
| Piloto preview | 1–2 sprints | Baixo |

---

## Retorno esperado (6 meses)

| Métrica | Meta |
|---------|------|
| Horas perdidas com ambiente instável | **-70%** |
| Falso positivo automação | **< 5%** |
| Re-testes por release | **-50%** |
| "Parem de usar QA" | **Zero** (calendário + previews) |
| Features testadas no QA compartilhado | **Tendendo a 0%** |

---

## Critérios de sucesso

1. QA recebe **apenas release candidates** promovidos por pipeline
2. Automação estável em `auto.youse.io` — flaky **< 5%**
3. **Zero** testes destrutivos no Stage
4. Provisionamento clone L1 **< 15 min**
5. **100% teardown** em automação efêmera
6. Handbook reflete a arquitetura real

---

<!-- _class: lead -->

# 6. Decisões

---

## O que pedimos ao CTO

| # | Decisão |
|---|---------|
| ✅ 1 | **Aprovar** a estratégia v2 (clone + ambientes fixos) |
| ✅ 2 | **Alocar** squad Plataforma (2–3 eng.) por 1 sprint de spike |
| ✅ 3 | **Nomear** 1 squad piloto + 1 repo (`sales-frontend`) |
| ✅ 4 | **Autorizar** repo `environment-platform` na org Youse |
| ✅ 5 | **Reservar** ~15–20% capacity headroom no EKS QA |

---

## Próximas 2 semanas (se aprovado)

| Semana | Ação |
|--------|------|
| 1 | Workshop QA + Plataforma → massa de dados v1 |
| 1 | Inventário 313 refs QA (planilha) |
| 2 | Spike: POC clone L1 (`deployment-orb` + namespace + seed) |
| 2 | Kickoff squad piloto |

---

<!-- _class: lead -->

# Obrigado

## Perguntas?

**Documentação completa:**
- `PROJETO-AMBIENTES-YOUSE-v2-CLONE.md`
- `PROJETO-AMBIENTES-YOUSE.pdf` (v1.3 + auditoria)

**Repositório:** github.com/gabrielroquim-youse/estrutura-ambientes-youse

---

<!-- _class: small -->

## Anexo — referência rápida de repos Youse

| Repo | Papel no projeto |
|------|------------------|
| `deployment-orb` | Jobs clone / destroy / promote |
| `gitops-kubernetes-addons` | Namespaces, quotas |
| `terraform-platform` | DNS, RDS, IAM |
| `qa-e2e-tests-automation` | Workflow efêmero YAML |
| `performance-tests` | Migrar para `perf.youse.io` |
| `handbook` | Atualizar `ambientes.md` |

---

## Anexo — cartilha por perfil (resumo)

**Dev:** feature em andamento → preview da branch · pós-merge → Stage

**QA:** tarefa em andamento → mesma URL do dev · release → QA/UAT (RC)

**Produto:** UAT após QA interno · nunca validar feature enquanto dev deploya no QA

**DevOps:** automate promote · TTL/destroy · perf/chaos fora do Stage
