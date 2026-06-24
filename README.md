# Estrutura de Ambientes Youse

> **POC executável** + documentação técnica da estratégia de **ambientes efêmeros por branch** ("1 PR = 1 ambiente preview") para a Youse Seguradora.

[![Status](https://img.shields.io/badge/status-POC%20validada-success)]() [![Stack](https://img.shields.io/badge/stack-Docker%20%7C%20PostgreSQL%2014%20%7C%20Node%2020-blue)]() [![License](https://img.shields.io/badge/uso-interno%20Youse-orange)]()

---

## 🎯 O que é este projeto

A Youse hoje usa **um único QA compartilhado** (`qa.youse.io`). Toda branch de toda squad disputa o mesmo banco, mesma URL, mesma massa de dados. Resultado: bugs intermitentes, releases represadas, testes E2E que dão "flaky" porque outra squad alterou dados no meio do teste.

Este repo prova — com **código rodável** — que dá pra:

1. **Criar um ambiente isolado por PR** em segundos (não minutos).
2. Sem **duplicar storage** no RDS (usa copy-on-write nativo do PostgreSQL).
3. Sem **mexer no QA existente**.
4. Com **dados reais clonados** (1 cópia por branch, isolada).
5. Destruindo tudo automaticamente quando o PR fecha.

> A estratégia é inspirada em **Vercel Preview Deployments / Heroku Review Apps**, adaptada ao stack AWS da Youse (RDS PostgreSQL, EKS, ECR, CircleCI).

---

## 📑 Índice

- [Como rodar a POC (5 min)](#-como-rodar-a-poc-5-min)
- [O que a POC demonstra](#-o-que-a-poc-demonstra)
- [De onde veio a base técnica](#-de-onde-veio-a-base-técnica)
- [Estrutura do repositório](#-estrutura-do-repositório)
- [Arquitetura (resumida)](#-arquitetura-resumida)
- [Roadmap](#-roadmap)
- [FAQ](#-faq)

---

## 🚀 Como rodar a POC (5 min)

### Pré-requisitos

- **Docker Desktop** instalado e em execução
- ~2 GB de RAM livre
- Portas livres: `3000`, `4000`, `5050`, `5433`, `8025`, `1025`

### Passos

```powershell
# 1. Clone o repo
git clone https://github.com/gabrielroquim-youse/estrutura-ambientes-youse.git
cd estrutura-ambientes-youse/environment-platform/poc-real/db/local-test

# 2. Sobe o stack inteiro (PG + clone job + API Node + frontend + Mailpit + pgAdmin)
docker compose -f docker-compose.cotacao-v2.yml up --build -d

# 3. Espera ~30s e abre no navegador:
```

| URL | O que é |
|---|---|
| http://localhost:3000 | **Landing** — réplica do `qa.youse.io`. Clica em **"COTE GRÁTIS"** no Auto. |
| http://localhost:8025 | **Caixa de entrada (Mailpit)** — vê o email da cotação chegar |
| http://localhost:5050 | **pgAdmin** (login: `poc@poc.com` / senha: `poc`) — explora `monolithic_qa` vs `preview_you_123` |
| http://localhost:4000/api/health | Health da API Node |

### Pra derrubar tudo

```powershell
docker compose -f docker-compose.cotacao-v2.yml down -v
```

📖 **Detalhes completos** da POC: [environment-platform/poc-real/db/local-test/README.md](environment-platform/poc-real/db/local-test/README.md)

---

## 🎬 O que a POC demonstra

A POC replica o **fluxo real de Seguro Auto da Youse** (`qa.youse.io` → "COTE GRÁTIS" → `cotacao.youse.com.br/seguro-auto/.../lead_info`) numa cópia visualmente próxima, rodando 100% local com Docker.

**Em 4 telas:**

1. **Home** com cards Auto/Residencial/Vida (Auto ativo)
2. **Lead info** — nome + email + telefone
3. **Veículo** — placa, marca, modelo, ano, FIPE
4. **Cotação** — prêmio calculado + email enviado de verdade

**Por baixo:**

- `postgres-qa-simulado` simula o RDS `monolithic-qa` da Youse (PG 14, mesma versão real)
- `clone-db-job` roda `CREATE DATABASE preview_you_123 TEMPLATE monolithic_qa` — **8s no local, <500ms no RDS real (estimado warm)**
- `api-cotacao` (Node + Express + nodemailer) calcula prêmio e dispara SMTP
- `mailpit` captura o email e mostra numa UI tipo Gmail
- O email mostra explicitamente que veio do banco clonado da branch — não do QA

> 💡 **Quer receber em e-mail real?** Descomente o bloco SMTP do Gmail em [docker-compose.cotacao-v2.yml](environment-platform/poc-real/db/local-test/docker-compose.cotacao-v2.yml) e reinicie a `api-cotacao`.

---

## 🧱 De onde veio a base técnica

Cada decisão da POC foi informada pelo **stack real da Youse**, mapeado a partir dos repos internos:

| Item | Fonte / Validação | Decisão na POC |
|---|---|---|
| Versão do PostgreSQL | Repo `terraform-platform` (RDS `monolithic-qa` = PG 14.22; `shared-qa-v12` = PG 12.11) | `postgres:14-alpine` na POC |
| Cluster RDS | Não é Aurora (confirmado no Terraform) — RDS comum, single-AZ em QA | `CREATE DATABASE TEMPLATE` funciona nativo |
| Stack AWS | Conta `514007640321`, região `sa-east-1`, role `arn:aws:iam::514007640321:role/circleci`, ECR `514007640321.dkr.ecr.sa-east-1.amazonaws.com` | Documentado em `rds-map.yaml` |
| Padrão de secrets | `qa/rds/admin/<rds-name>` no AWS Secrets Manager | Replicado em `clone-db.sh` (script production) |
| Network constraints | RDS aceita só VPC EKS-QA (`10.196.0.0/16`), VPC Core (`10.130.0.0/23`) e VPN GlobalProtect (`10.249.0.0/22`) | Pipeline final precisa rodar em self-hosted runner ou CircleCI |
| Fluxo de cotação | Mapeado de `qa.youse.io` e `cotacao.youse.com.br/seguro-auto/.../lead_info` | Frontend replica passos 1-2-3 |
| Visual / layout | Site público `qa.youse.io` (cores, logo "you**se**", cards, tipografia) | Replicado em HTML+CSS sem framework |

### Por que `CREATE DATABASE ... TEMPLATE`?

Foi a **peça crítica**: era preciso provar que dá pra clonar o banco de QA rápido o suficiente pra encaixar num pipeline de PR.

| Cenário | Tempo medido | Observação |
|---|---|---|
| Docker local (PG 14, ~50 MB) | **8.178 ms** | Cold start, primeiro clone |
| RDS warm (estimado) | **< 500 ms** | Com buffers OS aquecidos |
| Integridade FKs / índices / sequences | ✅ 100% | Validado via diff de schema |
| Isolamento alterações | ✅ Total | Mudança no preview NÃO vaza pro QA |

Snapshot RDS levaria minutos. Logical dump/restore idem. `TEMPLATE` é a única opção sub-segundo.

---

## 📁 Estrutura do repositório

```
estrutura-ambientes-youse/
│
├─ README.md                              ← você está aqui
├─ PROJETO-AMBIENTES-YOUSE-v2-CLONE.md    ← documento técnico longo
├─ PROJETO-AMBIENTES-YOUSE.pdf            ← versão PDF p/ apresentação
├─ .gitignore
│
├─ docs/                                  ← apresentações p/ stakeholders
│  ├─ APRESENTACAO-NOTAS-TIME-QUALIDADE.md
│  ├─ apresentacao-time-qualidade.md
│  ├─ apresentacao-time-infra.md
│  └─ GUIA-PRATICO-AMBIENTES-FERRAMENTAS.md
│
├─ .github/workflows/
│  └─ preview-environment.yml             ← workflow GH Actions de exemplo
│                                            (jobs: detect → clone-db → provision → destroy)
│
└─ environment-platform/
   │
   ├─ poc-real/                           ← 👈 PROVA DE CONCEITO EXECUTÁVEL
   │  └─ db/
   │     ├─ clone-db.sh                   ← script production (AWS Secrets + RDS real)
   │     ├─ rds-map.yaml                  ← mapa dos RDS reais da Youse (QA)
   │     └─ local-test/                   ← stack Docker rodável localmente
   │        ├─ docker-compose.cotacao-v2.yml  ← stack principal (use este)
   │        ├─ README.md                  ← guia detalhado da POC
   │        ├─ clone-db-init.sh           ← entrypoint do job de clone
   │        ├─ seed-qa-v2.sql             ← schema + massa do QA simulado
   │        ├─ pgadmin-servers.json
   │        ├─ api-cotacao/               ← API Node (Express + pg + nodemailer)
   │        │  ├─ Dockerfile
   │        │  ├─ package.json
   │        │  └─ server.js
   │        └─ frontend-cotacao/          ← 4 telas HTML (landing → lead → vehicle → quote)
   │           ├─ index.html
   │           ├─ lead_info.html
   │           ├─ vehicle.html
   │           └─ quote.html
   │
   ├─ golden-seed/                        ← seed "golden" (massa controlada)
   │  ├─ version.yaml
   │  ├─ manifests/users-auto.example.json
   │  └─ scripts/validate-seed.sh
   │
   ├─ poc-simulador/                      ← scripts shell de simulação inicial
   │  ├─ simulate-clone.sh
   │  └─ simulate-destroy.sh
   │
   └─ examples/                           ← payloads YAML de exemplo
      ├─ automation-ephemeral-request.yaml
      └─ branch-preview-request.yaml
```

---

## 🏗️ Arquitetura (resumida)

### POC local

```
Browser ──► nginx (frontend :3000) ──fetch──► Node (api :4000)
                                                  │
                                          ┌───────┴────────┐
                                          ▼                ▼
                                   PostgreSQL :5433    Mailpit :1025
                                   ├─ monolithic_qa    (UI :8025)
                                   └─ preview_you_123
                                      ↑
                                   (clonado via TEMPLATE)
```

### Produção (proposta)

```
GitHub PR opened
   │
   ▼
GH Actions / CircleCI (self-hosted runner na VPC)
   │
   ├─ detect-changed-services ──► lista de microsserviços alterados
   │
   ├─ clone-db.sh ──────────────► CREATE DATABASE preview_PR123
   │                              TEMPLATE monolithic_qa
   │                              (no RDS real, mesma instância)
   │
   ├─ deploy-services ──────────► só serviços alterados:
   │                              kubectl apply -f manifests/preview-PR123/
   │
   └─ comment on PR ────────────► URL: https://pr-123.preview.youse.dev
                                  mailpit / observability links
```

Quando o PR fecha, job `destroy` faz `DROP DATABASE preview_PR123` + `kubectl delete namespace preview-pr-123`.

---

## 🗺️ Roadmap

| Fase | Item | Status |
|---|---|---|
| **1. Validação técnica** | `CREATE DATABASE TEMPLATE` local | ✅ Validado (8s, integridade 100%) |
|  | POC visual fim-a-fim (landing → email) | ✅ Funcionando |
|  | Mapeamento dos RDS reais | ✅ Documentado |
| **2. Validação org** | Apresentação Time de Qualidade | 🔄 Em andamento |
|  | Apresentação Time de Infra | ⏳ Após feedback QA |
| **3. Validação prod** | Rodar `clone-db.sh` contra RDS real (VPN) | ⏳ Pendente (precisa permissão IAM) |
|  | Pipeline GH Actions self-hosted na VPC | ⏳ Pendente |
| **4. Piloto** | 1 squad usando preview-por-PR | ⏳ Pendente |
| **5. Rollout** | Todas as squads | ⏳ Futuro |

---

## ❓ FAQ

**P: Isso afeta `qa.youse.io`?**
R: Não. A POC roda 100% local. O `clone-db.sh` (production) sempre cria um banco **novo** (`preview_PRxxx`), nunca toca em `monolithic_qa`.

**P: Quanto custa em AWS?**
R: `CREATE DATABASE TEMPLATE` usa **copy-on-write** — só blocos modificados ocupam storage novo. Custo marginal por preview: poucos MB. Sem impacto significativo na fatura RDS.

**P: E se uma branch rodar uma migration?**
R: A migration roda só no banco daquela branch. Outras branches e o QA não são afetados. Quando o PR fecha, o banco é dropado junto.

**P: Funciona pra Aurora?**
R: Sim, mas a Youse usa RDS comum (confirmado no `terraform-platform`). `CREATE DATABASE TEMPLATE` funciona nos dois.

**P: Por que não usar `pg_dump` + `pg_restore`?**
R: Leva minutos pra bases médias. `TEMPLATE` é sub-segundo. Diferença crítica pra UX de PR (devs não esperam 10min pra ter um ambiente).

**P: Por que Mailpit e não SES de verdade?**
R: Pra POC local, Mailpit captura SMTP sem precisar de credencial AWS. Em produção, o `mailer-service` da Youse usa SES — o código nodemailer já está parametrizado p/ trocar via env var.

**P: Posso usar isso pra qualquer linguagem de backend?**
R: Sim. O clone do banco é agnóstico. A POC usa Node só pro mock — em produção, são os serviços reais (Ruby/Rails monolithic, Go pricing-engine etc.) que conectam no banco clonado.

---

## 📚 Documentação complementar

- 📘 [PROJETO-AMBIENTES-YOUSE-v2-CLONE.md](PROJETO-AMBIENTES-YOUSE-v2-CLONE.md) — documento técnico longo (arquitetura, custos, riscos)
- 📊 [docs/INVENTARIO-MICROSSERVICOS-YOUSE.md](docs/INVENTARIO-MICROSSERVICOS-YOUSE.md) — **inventário dos microsserviços reais** da Youse + candidatos a piloto
- 🎤 [docs/CALL-INFRA-PAUTA.md](docs/CALL-INFRA-PAUTA.md) — pauta pronta pra call com Infra (30 min, 3 decisões)
- 🧭 ADRs (Architecture Decision Records):
   - [ADR-001 — Routing preview ↔ QA](docs/ADR-001-routing-preview-qa.md)
   - [ADR-002 — Estratégia de bancos](docs/ADR-002-estrategia-bancos.md)
   - [ADR-003 — Isolamento de filas/SQS](docs/ADR-003-isolamento-filas.md)
- 🎤 [docs/apresentacao-time-qualidade.md](docs/apresentacao-time-qualidade.md) — versão p/ QA
- 🛠️ [docs/apresentacao-time-infra.md](docs/apresentacao-time-infra.md) — versão p/ Infra
- 🔧 [docs/GUIA-PRATICO-AMBIENTES-FERRAMENTAS.md](docs/GUIA-PRATICO-AMBIENTES-FERRAMENTAS.md) — comparativo de ferramentas
- 🧪 [environment-platform/poc-real/db/local-test/README.md](environment-platform/poc-real/db/local-test/README.md) — guia detalhado da POC executável

---

## 👤 Autoria

**Gabriel Roquim** — Time de Qualidade Youse · 2026

Repo: https://github.com/gabrielroquim-youse/estrutura-ambientes-youse
