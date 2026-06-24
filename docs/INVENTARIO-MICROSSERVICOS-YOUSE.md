# 📊 Inventário de Microsserviços Youse — Candidatos a Previews

> **Levantamento:** 2026-06-24
> **Fonte:** GitHub API — org [`youse-seguradora`](https://github.com/youse-seguradora) (467 repos totais; analisados os 100 mais recentemente atualizados)
> **Objetivo:** Identificar candidatos a microsserviços para a estratégia de **ambientes efêmeros por branch** ("1 PR = 1 preview environment")

---

## 📌 TL;DR

- **~30 microsserviços backend** ativos (maioria **Ruby on Rails**, alguns Python/Java)
- **~10 frontends/apps** (TypeScript/React, Flutter para mobile)
- **~20 componentes de infra** (Terraform, GitOps, Lambdas AWS)
- **Stack:** AWS-first, Kubernetes (EKS) + GitOps, Jenkins + CircleCI Orbs
- **Design system unificado:** [`Cargo`](https://github.com/youse-seguradora) (web + mobile)
- **Monolito legado:** repo `youse` ("Former monolith, being broken apart step-by-step") — 91 issues abertas

---

## 🎯 Top candidatos para o piloto

### 🥇 Tier 1 — Ideais para começar

| # | Serviço | Linguagem | Por quê |
|---|---|---|---|
| 1 | **`pricing-engine`** | Ruby | Core do negócio (cotação). Microsserviço desde 2016 (maduro). DB próprio (`pricing-engine-qa`, PG 14.22). Alinhado 100% com a POC atual. |
| 2 | **`policy-service`** | Ruby | Global service para apólices. Topic explícito: `microservice`. DB próprio implícito. Mais recente do top (atualizado hoje). |
| 3 | **`order-service`** | Ruby | "Sales journey orchestrator". Bom pra testar integração entre serviços. |
| 4 | **`billing-cloud`** | Ruby | Pagamentos. DB complexo (transações). Bom pra testar estado financeiro. |
| 5 | **`claims-service`** | Ruby | Sinistros. Lógica clara e testável. Integra com docs externos. |

### 🥈 Tier 2 — Próxima onda

| # | Serviço | Linguagem | Por quê |
|---|---|---|---|
| 6 | **`charge-service`** | Ruby | Operações de cartão de crédito. Bom teste de mocks/stubs. |
| 7 | **`documents`** | Ruby | Geração/assinatura de PDFs. Escopo fechado, usa S3 (bucket por preview possível). |
| 8 | **`c360`** | Ruby | Customer 360º view. Read-heavy. Bom teste de cache. |
| 9 | **`idp-service`** | Python | Identity Provider novo. Valida que estratégia funciona fora do Ruby. |
| 10 | **`support-services`** | Ruby | FIPE, Occupations, Addresses. Dados de referência, baixa complexidade. |

---

## 🏗️ Microsserviços Backend (catálogo completo dos ativos)

| Serviço | Linguagem | Última atualização | O que faz |
|---|---|---|---|
| `policy-service` | Ruby | 2026-06-24 | Operações de apólices |
| `pricing-engine` | Ruby | 2026-06-23 | Product spec e pricing engine |
| `coupon-service` | Ruby | 2026-06-23 | Cupons e promoções |
| `bff` | Ruby | 2026-06-23 | Backend For Frontend (Mobile) |
| `order-service` | Ruby | 2026-06-22 | Sales journey orchestrator |
| `partner-api` | Ruby | 2026-06-22 | API pública pra cotações de parceiros |
| `support-services` | Ruby | 2026-06-19 | FIPE, Occupations, Addresses |
| `assistances-service` | Ruby | 2026-06-19 | Assistências |
| `test-utils-service` | Ruby | 2026-06-19 | Test utility service |
| `billing-cloud` | Ruby | 2026-06-18 | Pagamentos in/out |
| `partners-service` | Ruby | 2026-06-17 | Allies/partners e comissões |
| `claims-service` | Ruby | 2026-06-15 | Sinistros |
| `inspection-service` | Ruby | 2026-06-12 | Inspeção de veículos |
| `commission-service` | Ruby | 2026-06-12 | Gestão de comissões |
| `capitalization-service` | Ruby | 2026-06-11 | Capitalizações |
| `risk-acceptance` | Ruby | 2026-06-09 | Verdict sobre segurados |
| `sales-service` | Ruby | 2026-06-01 | Leads, scoring, distribuição |
| `call-center-bff` | Ruby | 2026-05-25 | BFF do call center |
| `charge-service` | Ruby | 2026-05-14 | Cartão de crédito |
| `bonus-class-service` | Ruby | 2026-05-12 | Classe de bônus |
| `c360` | Ruby | 2026-05-08 | Customer 360º |
| `documents` | Ruby | 2026-05-08 | Geração de PDFs |
| `messaging-gateway` | Ruby | 2026-05-08 | HTTP↔AMQP para parceiros |
| `predict-service` | Ruby | 2026-05-04 | ML models orchestration |
| `idp-service` | Python | 2026-04-30 | Identity Provider (novo) |
| `communication-cognito-service` | Java | 2026-04-16 | Cognito integration |
| `survey-service` | Ruby | 2026-03-20 | Survey management |
| `admin` | Ruby | 2026-02-20 | Admin dashboard |
| `opin-service` | Java | 2026-01-20 | Opinião de riscos |

---

## 🌐 Frontends / Mobile

| App | Linguagem | Última atualização | Notas |
|---|---|---|---|
| `mob-flutter` | Dart | 2026-06-24 | App mobile (Android + iOS) |
| `sales-frontend` | TypeScript | 2026-06-23 | Monorepo Lerna — sales frontends |
| `tiny-fronts` | TypeScript | 2026-06-22 | Micro-frontends React. **Excelente pra previews** (deploy independente). |
| `institutional-pages-bra` | TypeScript | 2026-06-01 | Site institucional (Gatsby + DatoCMS) |
| `inspections` | TypeScript | 2026-05-25 | Frontend de inspeções |
| `ombudsman-portal` | TypeScript | 2026-05-25 | Ouvidoria |
| `idp-frontend` | TypeScript | 2026-04-23 | Frontend do IDP |
| `pizza-party` | TypeScript | 2026-05-21 | Cliente QA do test-utils-service |

---

## 📊 Data / Analytics

| Repo | Linguagem | Notas |
|---|---|---|
| `airflow-dags` | Python | Pipelines Airflow |
| `youse-datapipeline` | Python | Pipeline novo |
| `data-pipeline` | Scala | Spark/Scala |
| `looker-data-model` | LookML | Modelos Looker |

---

## 🚀 Infra / DevOps (referência)

Repos importantes que mostram o stack atual:

| Repo | Pra que serve |
|---|---|
| `terraform-platform` | Root Terraform (EKS, LBs, RDS) — **fonte primária** do stack |
| `gitops-kubernetes-addons` | GitOps p/ K8s addons (ArgoCD implícito) |
| `deployment-orb` | CircleCI Orb p/ deploys |
| `youse-jenkins-v2` | Jenkins v2 |
| `platform-automations` | Lambdas (incident response, cost, compliance) |
| `devops` | Ansible, SRE scripts |

---

## 🧪 QA / Testes

| Repo | Stack |
|---|---|
| `qa-e2e-tests-automation` | TypeScript |
| `qa-api-tests-automation` | TypeScript |
| `qa-mobile-tests-automation` | TypeScript |
| `qa-copilot-test-planner` | JavaScript (AI-powered) |
| `platform-automated-testing` | Ruby |
| `performance-tests` | JavaScript |

---

## 🏛️ Insights arquiteturais

### Monolito principal
**`youse`** (Ruby, atualizado 2026-06-22) — descrição: *"Former monolith, being broken apart step-by-step. Has sales journey, accounts, mobile API and admin/manager."*

- 91 issues abertas = legado em transição
- Muitos serviços ainda dependem parcialmente dele
- **Implicação pra previews:** estratégia precisa contemplar o caso de PRs no monolito (que afetam várias áreas)

### Padrões de naming
- `-service` em ~20 repos
- `-engine` p/ motores de cálculo
- `gw-*` p/ integrações Guidewire (~8 repos)
- `csp-lambda-*` p/ CloudSecure Platform Lambdas
- `cargo-*` p/ design system

### Design system unificado: **Cargo**
- `cargo-components` (React)
- `cargo-design-system-web`
- `cargo-design-system-app` (Flutter)
- `cargo-design-system-utils`

### Linguagens (distribuição estimada)
- **Ruby** ~65% (Rails)
- **TypeScript** ~20% (frontends + Lambdas modernas)
- **Python** ~8% (data + automações + IDP)
- **Java/Gosu** ~4% (Guidewire, OPIN)
- **HCL** ~12% (Terraform/IaC)

---

## 🗺️ Plano de adoção sugerido

### 🌊 Fase 1 — MVP (1 serviço, 2-3 semanas)
**`pricing-engine`** isolado:
- Clone `pricing-engine-qa` → `pricing_pr<N>`
- Deploy 1 pod no EKS namespace `preview-pr-<N>`
- Demais serviços herdados do QA
- **Métrica de sucesso:** PR fake passa pelo fluxo completo de cotação

### 🌊 Fase 2 — Fluxo crítico (3 serviços, 4-6 semanas)
- `pricing-engine` ✅
- `order-service` (orquestrador da cotação)
- `sales-frontend` (UI)
- **Métrica de sucesso:** time de QA roda E2E real num preview

### 🌊 Fase 3 — Heterogeneidade (5+ serviços, ongoing)
Adicionar sob demanda, conforme squads pedem:
- `policy-service`, `billing-cloud`, `claims-service`
- Testar com `idp-service` (Python) p/ validar fora do Ruby
- Avaliar `tiny-fronts` (micro-frontend independente)

---

## 🔗 Próximas ações

1. **Confirmar com Infra/DevOps** os candidatos do Tier 1
2. **Mapear o banco de cada serviço Tier 1** (qual RDS, qual database) — pode validar via `terraform-platform`
3. **Verificar Dockerfile + CI** dos serviços piloto (precisa imagem buildável)
4. **Definir estratégia de routing** (Istio? Linkerd? Só DNS?) — pré-requisito p/ Fase 1
5. **Definir estratégia de filas/SQS** isoladas por preview
