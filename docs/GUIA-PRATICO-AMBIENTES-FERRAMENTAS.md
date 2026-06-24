# Guia Prático — Ambientes, Ferramentas e Implementação

**Projeto:** Ambientes por Clone (Golden Template)  
**Público:** Time de Qualidade (agora) → Infra (depois)  
**Versão:** 1.0 | Junho/2026

Este documento descreve **como cada ambiente funciona na prática**, **quais ferramentas usar** e **o que dá para testar sem o time de Infra**.

---

## 1. Mapa de ambientes — visão prática

| Ambiente | URL | Tipo | Quem usa | Ferramentas principais |
|----------|-----|------|----------|------------------------|
| **Golden QA** | interno (sem URL pública) | Fixo (template) | Plataforma | EKS, Helm, seed script, CronJob |
| **Preview branch** | `you-123.preview.youse.io` | Clone efêmero | Dev + QA | CircleCI, `deployment-orb`, Helm, Route53 |
| **Auto ephemeral** | `run-789.auto-preview.youse.io` | Clone efêmero | Automação PR | GitHub Actions, Playwright, YAML |
| **Stage** | `www-stage.youse.io` | Fixo (release) | CI pós-merge | CircleCI, Helm `.helm/stage.yaml` |
| **Automation** | `auto.youse.io` | Fixo (release) | Regressão E2E | Playwright, gate promote |
| **QA / UAT** | `qa.youse.io` | Fixo (release) | RC + Produto | Pipeline promote only |
| **Pre-Prod** | `preprod.youse.io` | Fixo (release) | Smoke final | Terraform, Helm |
| **Perf / Chaos** | `perf.youse.io` | Fixo (especializado) | SRE, k6 | `performance-tests`, janela agendada |

---

## 2. Stack de ferramentas por camada

### 2.1 Infraestrutura (time Infra — fase 2)

| Camada | Ferramenta Youse | Função no clone |
|--------|------------------|-----------------|
| Orquestração | **Amazon EKS** | Namespace isolado por preview |
| Deploy apps | **Helm** (`.helm/qa.yaml`, `.helm/stage.yaml`) | Valores por ambiente/branch |
| CI/CD | **CircleCI** + **`deployment-orb`** | Jobs: `clone`, `deploy-overlay`, `destroy` |
| IaC | **Terraform** + **Atlantis** | DNS, RDS, IAM, Route53 |
| Config legado | **Ansible** (`devops/ansible_v2`) | Vars por ambiente |
| GitOps K8s | **`gitops-kubernetes-addons`** | Quotas, NetworkPolicy, addons |
| Secrets | **AWS SSM** / Vault | Secrets por namespace (nunca copiar prod) |
| DNS / TLS | **Route53** + **cert-manager** | `*.preview.youse.io` |
| Banco | **RDS PostgreSQL** | Snapshot restore ou schema+seed |
| Observabilidade | **Datadog** | Tags por namespace/preview |

### 2.2 Dados e config (time Qualidade — agora)

| Camada | Ferramenta | Função |
|--------|------------|--------|
| Massa de dados | **`golden-seed/`** (YAML/JSON versionado) | CPFs, apólices, usuários de teste |
| Feature flags | Registry YAML + LaunchDarkly/Unleash (sandbox) | Snapshot congelado no golden-automation |
| Validação seed | Script `validate-seed.sh` | Smoke pós-clone |
| Contrato de ambiente | **`EphemeralEnvironment` YAML** | Pedido declarativo de clone |
| Automação E2E | **Playwright** (`qa-e2e-tests-automation`) | Target URL dinâmica |
| API tests | **Insomnia/Postman** collections | Requests por ambiente |
| Mocks externos | **WireMock** / Prism | Integrações sandbox |

### 2.3 Orquestração do ciclo de vida (evolução)

| Fase | Implementação | Quem monta |
|------|---------------|------------|
| **POC (sem Infra)** | Scripts + GitHub Actions no repo `estrutura-ambientes` | Qualidade |
| **Piloto L1** | CircleCI jobs no `deployment-orb` | Infra + Qualidade |
| **Produção** | K8s Operator + CRD `EphemeralEnvironment` | Infra |

---

## 3. Como funciona um clone — passo a passo técnico

### 3.1 Preview por branch (Dev + QA)

```
┌──────────────┐     webhook      ┌─────────────────┐
│ GitHub       │ ───────────────► │ Control Plane   │
│ feature/YOU-123                │ (orb ou Operator)│
└──────────────┘                  └────────┬────────┘
                                           │
         ┌─────────────────────────────────┼─────────────────────────┐
         ▼                                 ▼                         ▼
  ┌─────────────┐                  ┌─────────────┐           ┌─────────────┐
  │ Namespace   │                  │ DB clone ou │           │ Route53     │
  │ preview-123 │                  │ seed script │           │ you-123.    │
  │ no EKS      │                  │ golden-seed │           │ preview...  │
  └─────────────┘                  └─────────────┘           └─────────────┘
         │
         ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ Helm install: serviços da branch (overlay)                   │
  │ + serviços não alterados → rota para Stage (modelo L1)      │
  └─────────────────────────────────────────────────────────────┘
         │
         ▼
  URL: https://you-123.preview.youse.io
  Notifica: Slack #ambientes-youse + comentário no Jira YOU-123
```

**Sequência detalhada:**

1. Dev faz push em `feature/YOU-123-nova-cotacao`
2. Webhook CircleCI/GitHub dispara job `clone-environment`
3. Control Plane lê template `golden-qa` (versão + seed `2026.06.1`)
4. Cria namespace `preview-you-123` no EKS com ResourceQuota
5. Executa `seed-idempotent.sh` (dados do golden-seed) no DB do preview
6. `helm upgrade --install` com `values-preview.yaml` + imagem da branch
7. Serviços não alterados: Ingress aponta para Stage (L1 híbrido)
8. Registra DNS `you-123.preview.youse.io` → Ingress do namespace
9. Roda `validate-seed.sh` — se falhar, marca ambiente como `Failed`
10. Posta URL no Slack e no card Jira
11. **Destroy:** merge/close PR ou TTL 72h → `destroy-environment` remove namespace + DNS + DB clone

### 3.2 Automação efêmera (YAML → teste → destroy)

```yaml
# Disparado por GitHub Actions no qa-e2e-tests-automation
spec:
  sourceTemplate: golden-automation
  teardownPolicy: Always
  tests:
    suite: smoke
    targetUrl: https://run-${{ github.run_id }}.auto-preview.youse.io
```

**Sequência:**

1. Workflow lê YAML `EphemeralEnvironment`
2. Clona `golden-automation` (toggles congelados, seed E2E)
3. Aplica versões de serviço do PR (se houver)
4. `npx playwright test --project=smoke` contra `targetUrl`
5. Publica relatório (artefato GHA)
6. **Sempre** executa `destroy` — sucesso, falha ou cancelamento

### 3.3 Ambientes fixos de release

| Transição | Gatilho | Ferramenta |
|-----------|---------|------------|
| main → Stage | Merge na main | CircleCI `deploy-stage` |
| Stage → Automation | Gate G1 verde | `deployment-orb` `promote-to-automation` |
| Automation → QA/UAT | E2E ≥ 98% (7 dias) | `promote-to-qa` |
| QA → Pre-Prod | Sign-off QA + Produto | `promote-to-preprod` |
| Pre-Prod → Prod | Aprovação release manager | Janela de deploy |

---

## 4. Golden Template — como é montado na prática

### 4.1 Conteúdo do golden-qa (exemplo)

```
golden-templates/golden-qa/
├── helm-values.yaml          # versões dos serviços (espelho Stage)
├── feature-flags.snapshot.yaml
├── integrations.yaml         # URLs sandbox (não prod)
└── kustomization.yaml

golden-seed/
├── version.yaml              # 2026.06.1
├── manifests/
│   ├── users-auto.json       # 10 contas login
│   ├── policies-auto.json    # apólices por fluxo
│   └── quotes-smoke.json
└── scripts/
    ├── seed-idempotent.sh
    └── validate-seed.sh
```

### 4.2 Refresh diário (job agendado)

```
CronJob 03:00 BRT
  → Deploy versões atuais do Stage no golden-qa
  → Roda seed-idempotent.sh
  → Roda validate-seed.sh
  → Se falhar → alerta Slack #ambientes-youse
  → Atualiza golden-seed/version.yaml se massa mudou
```

---

## 5. Modelo L1 (piloto) — o mais realista para começar

Para a Youse, com 461 repos e microserviços, o piloto **não clona tudo**:

| Componente | No preview L1 | Aponta para |
|------------|---------------|-------------|
| `sales-frontend` (alterado) | Deploy no namespace preview | — |
| `order-service` (não alterado) | — | Stage |
| `youse` monolith (não alterado) | — | Stage |
| Massa de dados | Seed do golden-qa no DB preview* | — |
| Feature flags | Snapshot golden-qa | — |

\* No L1 mais simples, dados podem ser **contas reservadas** no golden-seed usadas só por aquele preview (sem DB clone) — ver seção 7.

---

## 6. Ferramentas por tipo de ambiente (resumo)

### Preview branch
- **Provisionar:** Terraform (DNS) + Helm + CircleCI orb
- **Dados:** golden-seed scripts
- **Acesso:** URL única por branch
- **Destruir:** TTL CronJob + webhook merge

### Golden templates
- **Manter:** Helm + CronJob refresh
- **Dados:** golden-seed versionado no Git
- **Validar:** validate-seed.sh

### Automation fixo (`auto.youse.io`)
- **Deploy:** promote pipeline Stage → Automation
- **Testes:** Playwright scheduled + on-promote
- **Governança:** toggles congelados em YAML (PR para alterar)

### Automation efêmera
- **Orquestrar:** GitHub Actions
- **Contrato:** EphemeralEnvironment YAML
- **Testar:** Playwright
- **Destruir:** `teardownPolicy: Always`

### Perf/Chaos
- **Carga:** k6 (`performance-tests`)
- **Caos:** LitmusChaos ou ferramenta SRE
- **Agenda:** calendário (nunca no Stage)

---

## 7. O que dá para fazer SEM o time de Infra?

### Resposta curta

| Objetivo | Sem Infra? |
|----------|------------|
| Clone real com URL `*.preview.youse.io` no EKS | **Não** |
| Validar conceito, massa de dados e automação | **Sim** |
| Simular ciclo de vida clone no nosso projeto | **Sim** |
| Rodar E2E com isolamento parcial de dados | **Sim** |
| Provar valor para o time de Qualidade | **Sim** |

### 7.1 O que EXIGE Infra

- DNS wildcard `*.preview.youse.io` (Route53 + certificado)
- Namespace novo no EKS + quotas
- Clone de banco RDS (snapshot) ou instância dedicada
- Alteração no `deployment-orb` (repo da org)
- IAM, NetworkPolicy, secrets por preview
- Integração CircleCI ↔ cluster QA

**Sem isso, não existe preview real na infra Youse.**

### 7.2 O que Qualidade pode fazer AGORA (neste repo)

#### A) Golden-seed v1 (prioridade máxima)

Montar o catálogo de massa de dados — **não precisa de Infra**:

```
environment-platform/golden-seed/
├── version.yaml
├── manifests/
│   ├── users-auto.json
│   ├── policies-auto.json
│   └── feature-flags-baseline.yaml
└── scripts/
    ├── validate-seed.sh      # valida JSON/schema localmente
    └── seed-idempotent.sh    # documenta o que rodaria no clone
```

**Entrega:** QA sabe exatamente quais contas/dados cada fluxo usa.

#### B) Simulador de ciclo de vida (POC)

Scripts que **simulam** create → test → destroy sem subir infra:

```
environment-platform/poc-simulador/
├── simulate-clone.sh         # lê YAML, gera URL fictícia, log de steps
├── simulate-destroy.sh
└── workflows/
    └── validate-environment-yaml.yml   # GHA: valida schema do YAML
```

GitHub Actions valida se o YAML `EphemeralEnvironment` está correto — **zero dependência de EKS**.

#### C) Automação com "ambiente lógico" (isolamento por conta)

Enquanto não há preview real, usar **contas reservadas por run** no QA existente:

| Run ID | Conta golden-seed | Uso |
|--------|-------------------|-----|
| `run-001` | `qa-auto-smoke-01@youse.test` | Suite smoke |
| `run-002` | `qa-auto-smoke-02@youse.test` | PR paralelo |

Playwright recebe `TEST_USER` e `BASE_URL` via env — padrão já usado em `qa-e2e-tests-automation`.

**Limitação:** ainda compartilha o mesmo `qa.youse.io`, mas **dados não colidem** entre runs se cada suite usar conta dedicada.

#### D) Workflow YAML efêmero (sem clone real)

No `qa-e2e-tests-automation` (repo pessoal/espelho):

```yaml
# .github/workflows/ephemeral-e2e-poc.yml
on: workflow_dispatch
jobs:
  e2e-ephemeral:
    steps:
      - name: Parse environment request
        run: ./scripts/parse-ephemeral-yaml.sh
      - name: Run Playwright (QA + conta isolada)
        env:
          BASE_URL: https://qa.youse.io
          TEST_ACCOUNT: ${{ steps.parse.outputs.account }}
      - name: Teardown (release account lock)
        if: always()
        run: ./scripts/release-test-account.sh
```

**Simula** o padrão create → test → destroy sem namespace K8s.

#### E) Mocks para dependências externas

Para testes locais ou CI sem backend completo:

| Ferramenta | Uso |
|------------|-----|
| **WireMock** | Mock de APIs parceiras |
| **MSW** | Mock no frontend (sales-frontend) |
| **Docker Compose** | 1–2 serviços locais (se tiver Dockerfile) |

#### F) Docker Compose local (opcional)

Mini-stack para demonstrar o conceito de "clone" localmente:

```yaml
# environment-platform/poc-simulador/docker-compose.yml
services:
  mock-order-api:
    image: wiremock/wiremock
  sales-frontend:
    build: ../../sales-frontend  # se tiver acesso
    environment:
      API_URL: http://mock-order-api:8080
```

Roda na máquina do QA — **prova o fluxo**, não substitui preview Youse.

---

## 8. Roadmap prático em duas trilhas

### Trilha A — Qualidade (sem Infra) · 2–4 semanas

| Semana | Entrega | Ferramenta |
|--------|---------|------------|
| 1 | golden-seed v1 (contas, apólices, fluxos Auto) | YAML/JSON no Git |
| 1 | validate-seed.sh | Bash + JSON Schema |
| 2 | Workflow GHA valida EphemeralEnvironment YAML | GitHub Actions |
| 2 | Playwright com contas isoladas por run | qa-e2e-tests-automation |
| 3 | simulate-clone.sh + documentação | Este repo |
| 4 | Apresentar resultados para Infra com evidências | Marp + métricas |

### Trilha B — Infra (após validação QA) · 4–8 semanas

| Semana | Entrega | Ferramenta |
|--------|---------|------------|
| 1 | DNS `*.preview.youse.io` | Terraform |
| 2 | Job `clone-environment` no deployment-orb | CircleCI |
| 3 | Piloto L1 sales-frontend + 1 squad | EKS + Helm |
| 4 | destroy + TTL + métricas | CronJob + Datadog |

---

## 9. O que montar neste repositório (estrutura sugerida)

```
environment-platform/
├── golden-seed/                    # ← Qualidade começa aqui
│   ├── version.yaml
│   ├── manifests/
│   └── scripts/
├── poc-simulador/                  # ← POC sem Infra
│   ├── simulate-clone.sh
│   ├── simulate-destroy.sh
│   ├── schemas/
│   │   └── ephemeral-environment.schema.json
│   └── docker-compose.yml          # opcional
├── examples/
│   ├── branch-preview-request.yaml
│   └── automation-ephemeral-request.yaml
└── .github/workflows/
    └── validate-environment-yaml.yml
```

---

## 10. Critérios: quando estamos prontos para pedir Infra

Checklist antes de ir para o time de Infra:

- [ ] golden-seed v1 documentado e validado por QA
- [ ] Fluxos Auto prioritários mapeados (smoke, cotação, emissão)
- [ ] Playwright rodando com contas isoladas (mesmo em QA compartilhado)
- [ ] YAML `EphemeralEnvironment` validado por schema
- [ ] Simulador de ciclo de vida funcionando no GHA
- [ ] Métricas baseline: flaky rate, tempo de setup, conflitos no QA
- [ ] Squad piloto e repo piloto definidos (`sales-frontend`?)

**Com isso, Infra recebe requisito claro — não conceito abstrato.**

---

## 11. Perguntas frequentes

### "Podemos ter clone de verdade só com GitHub Actions?"
Não no EKS da Youse. GHA sozinho não cria namespace nem DNS interno. GHA **orquestra** o clone quando Infra expõe API/jobs.

### "Podemos testar o conceito no nosso projeto pessoal?"
**Sim.** golden-seed + simulador + Playwright com contas isoladas + validação YAML.

### "Isso substitui o preview real?"
Não. Prova o **processo** e a **massa de dados**. Preview real vem na Trilha B.

### "Precisamos de banco clone no piloto?"
Não obrigatoriamente no L1. Contas reservadas no golden-seed + QA existente podem bastar para validar com Qualidade. DB clone entra no L2 com Infra.

---

*Documento complementar ao [PROJETO-AMBIENTES-YOUSE-v2-CLONE.md](../PROJETO-AMBIENTES-YOUSE-v2-CLONE.md)*
