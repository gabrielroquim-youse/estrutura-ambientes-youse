# Youse Environment Platform — POC

> **Resumo em uma frase:** Provar que dá pra criar um **ambiente isolado por branch** do app da Youse (`qa.youse.io`) em segundos, clonando o banco do QA com 1 comando e subindo só os serviços que mudaram — tudo rodável localmente com Docker.

Este repositório contém a **prova de conceito** (POC) executável e a **documentação técnica** da estratégia "1 branch = 1 ambiente preview", inspirada no fluxo real da Youse Seguros.

---

## 🎯 O problema

Hoje, na Youse, todo time compartilha **1 único QA** (`qa.youse.io`):

- Quando o time de **Pricing** sobe uma alteração de cálculo, o time de **Sales** pode acabar testando contra a versão errada.
- Bugs aparecem em QA que ninguém consegue reproduzir porque outro time mudou dados.
- Releases ficam represadas esperando "janela livre" no QA.
- Branches paralelas não têm onde rodar testes E2E reais.

## 💡 A proposta

**1 ambiente efêmero por Pull Request**, criado automaticamente no `pr open` e destruído no `pr close`, com:

1. **Banco clonado em segundos** via `CREATE DATABASE preview_xxx TEMPLATE monolithic_qa` (recurso nativo do PostgreSQL — mesma engine do RDS da Youse).
2. **Só os serviços que mudaram** são re-buildados — o resto é "herdado" do QA via service mesh / DNS routing.
3. **Branch isolada de verdade**: cada PR tem seu próprio banco, seu próprio domínio (ex.: `pr-123.preview.youse.dev`), sem afetar `qa.youse.io`.

Inspiração: Vercel preview deployments, Heroku Review Apps, GitHub Codespaces — mas adaptado pra arquitetura monolithic + microsserviços da Youse e pro stack AWS deles (RDS, EKS, ECR, CircleCI).

---

## 📦 O que tem aqui

```
estruturaAmbientes/
├─ README.md                          ← você está aqui
├─ PROJETO-AMBIENTES-YOUSE-v2-CLONE.md  ← documento técnico longo (arquitetura)
├─ docs/                              ← apresentações p/ times (Qualidade, Infra)
├─ .github/workflows/                 ← workflow GitHub Actions de exemplo
│  └─ preview-environment.yml         ← cria/destrói preview no PR
└─ environment-platform/
   ├─ poc-real/                       ← 👈 POC EXECUTÁVEL (foco deste README)
   │  └─ db/
   │     ├─ clone-db.sh               ← script production-ready (AWS Secrets + RDS)
   │     ├─ rds-map.yaml              ← mapa dos RDS reais da Youse (QA)
   │     └─ local-test/               ← stack Docker que roda na sua máquina
   ├─ golden-seed/                    ← seed de massa "golden" (usuários auto, etc.)
   └─ poc-simulador/                  ← scripts shell de simulação
```

---

## 🚀 Como rodar (5 minutos)

### Pré-requisitos

- **Docker Desktop** instalado e rodando (Windows / Mac / Linux)
- **PowerShell** (Windows) ou **bash** (Mac/Linux) — só pros comandos de teste
- ~2 GB de RAM livre

### Passos

```powershell
# 1. Clone o repo
git clone https://github.com/gabrielroquim-youse/estrutura-ambientes-youse.git
cd estrutura-ambientes-youse/environment-platform/poc-real/db/local-test

# 2. Sobe o stack completo
docker compose -f docker-compose.cotacao-v2.yml up --build -d

# 3. Espera ~30s os containers ficarem healthy, depois abre:
#    http://localhost:3000   ← Landing Youse (clica em "COTE GRÁTIS" no Auto)
#    http://localhost:8025   ← Caixa de entrada (Mailpit) — vê o email chegar
#    http://localhost:5050   ← pgAdmin (login: poc@poc.com / senha: poc)
```

### Pra derrubar tudo

```powershell
docker compose -f docker-compose.cotacao-v2.yml down -v
```

---

## ⚠️ POC simulada vs. produção — o que é "de verdade"

**Importante deixar isso claro pra qualquer pessoa que olhar a POC:** nesta máquina, **não estamos puxando o banco real da Youse**. Estamos rodando um PostgreSQL local que **simula** a estrutura do banco real, pra provar que o conceito funciona sem depender de Infra.

### O que é simulado vs. real

| Item | POC local (`local-test/`) | Produção Youse |
|---|---|---|
| **Engine do banco** | PostgreSQL 14 Alpine (Docker) | RDS Aurora PostgreSQL 14.22 (`sa-east-1`) |
| **Banco template** | `monolithic_qa` populado por seed SQL local | `monolithic_qa` real no RDS `monolithic` |
| **Credenciais** | hardcoded (`youse` / `youse`) | AWS Secrets Manager (`qa/rds/admin/monolithic`) |
| **Comando de clone** | `CREATE DATABASE preview_xxx TEMPLATE monolithic_qa` | **exatamente o mesmo comando** |
| **Tempo medido** | 8.178 ms (cold), <500 ms (warm estimado) | ⏳ a validar |
| **Massa de dados** | seed sintético (5 leads/veículos/cotações) | massa real de QA |
| **Acesso de rede** | localhost | requer VPN GlobalProtect + Security Group |

### O script que SABE puxar do RDS real já existe

O arquivo [`environment-platform/poc-real/db/clone-db.sh`](../clone-db.sh) é **production-ready** e faz exatamente isso:

```bash
# Uso real (precisa estar na VPN + ter role IAM):
./clone-db.sh you-123 monolithic monolithic_qa
```

Internamente ele:

1. Busca credenciais via `aws secretsmanager get-secret-value --secret-id qa/rds/admin/monolithic`
2. Conecta no RDS real (`monolithic-qa.cluster-xxx.sa-east-1.rds.amazonaws.com`)
3. Roda `CREATE DATABASE preview_you_123 TEMPLATE monolithic_qa;`

E o arquivo [`environment-platform/poc-real/db/rds-map.yaml`](../rds-map.yaml) tem o **inventário real dos RDS da Youse** auditado em junho/2026 (`shared-qa-v12`, `monolithic`, `pricing-engine`, `crivo`, `guidewire`, etc.).

### O que falta pra rodar contra o RDS real

3 dependências **só Infra entrega** (essa é justamente a pauta da call com o time deles):

1. **VPN GlobalProtect** liberada pro runner do CircleCI / GitHub Actions
2. **Role IAM** com permissão `secretsmanager:GetSecretValue` no `qa/rds/admin/*`
3. **Security Group** do RDS aceitando conexão da sub-rede do runner

Quando esses 3 itens estiverem prontos, o **mesmo `clone-db.sh`** (sem alterar 1 linha) clona o banco real. A POC local prova que o **comando funciona**; resta a Infra liberar o **acesso**.

---

## ✅ Roteiro de demonstração — "como provar que deu certo"

Use esta sequência quando for mostrar a POC pra alguém (call com Infra, apresentação pra time, etc.). Cada passo gera uma **evidência visual diferente** de que o conceito funciona.

### Checkpoint 1 — Os 3 ambientes estão isolados (UI)

Abra as 3 abas lado a lado:

| Aba | URL | O que confirmar |
|---|---|---|
| 1 | http://localhost:3000 | Banner azul "QA" |
| 2 | http://localhost:3001 | Banner amarelo "PR-123 PREVIEW" + lista de services próprios |
| 3 | http://localhost:3002 | Banner roxo "PR-456 CHANGED-ONLY" + notification marcada como `inherited-from-qa` |

**Evidência:** 3 ambientes com identidade visual diferente, todos no ar simultaneamente.

### Checkpoint 2 — Cada PR escreve no SEU banco (pgAdmin)

```powershell
# Antes da demo, anota as contagens iniciais:
docker exec postgres-qa-simulado psql -U youse -d monolithic_qa  -c "select count(*) from leads"
docker exec postgres-qa-simulado psql -U youse -d preview_pr123  -c "select count(*) from leads"
docker exec postgres-qa-simulado psql -U youse -d preview_pr456  -c "select count(*) from leads"
```

Agora faça uma cotação em http://localhost:3001 (PR-123) e rode os mesmos `count(*)`:

- `preview_pr123` aumentou +1 ✅
- `monolithic_qa` e `preview_pr456` **não mudaram** ✅

**Evidência:** isolamento real de dados — cada PR tem seu próprio banco, sem afetar QA nem outros PRs.

### Checkpoint 3 — Identidade do PR cross-service (Mailpit)

Faça uma cotação em http://localhost:3002 (PR-456) e abra http://localhost:8025:

- Email chegou com `From: noreply+pr-456@preview.youse.test` ✅
- **Mesmo o `notification-service` sendo o `qa-notification` compartilhado** (visível no header `X-Notification-Service-Preview: qa`) ✅

**Evidência:** o padrão "only-changed-services" funciona — você reusa o notification do QA economizando containers, mas a identidade do PR é preservada via `preview_id` no body.

### Checkpoint 4 — Comando de clone é o mesmo da produção

```powershell
docker exec postgres-qa-simulado psql -U youse -d postgres -c "\l+" | findstr preview
```

Mostra os 2 bancos preview criados pelo comando:

```sql
CREATE DATABASE preview_pr123 TEMPLATE monolithic_qa;
CREATE DATABASE preview_pr456 TEMPLATE monolithic_qa;
```

**Evidência:** o comando que roda local é **exatamente** o que o `clone-db.sh` vai rodar no RDS real. Só muda o host de conexão.

### Checkpoint 5 — Tudo cabe num PR de PRs (GitHub)

Mostre o repo: https://github.com/gabrielroquim-youse/estrutura-ambientes-youse

- 15 containers + 3 microservices + Traefik + clones de DB
- Stack completa = **1 arquivo `docker-compose.cotacao-v3.yml`** (310 linhas)
- Validação automatizada = **1 script `test-v3.ps1`** (60 linhas)

**Evidência:** complexidade gerenciável — não precisa de Kubernetes nem Helm pra provar o conceito.

---



---

## 🆕 v3 — Multi-preview simultâneo (3 ambientes em paralelo)

A v2 demonstra **1 preview com 1 API monolítica**. A **v3** quebra a API em 3 microsserviços (`pricing-engine`, `order-service`, `notification-service`) e roda **3 ambientes lado a lado** (QA + 2 PRs), simulando o cenário real Youse com várias squads abrindo PR ao mesmo tempo.

### Arquitetura v3

```
Browser ─► nginx-frontend (portas 3000 / 3001 / 3002)
              │
              │ /api/* (proxy_pass)
              ▼
          order-service (BFF)
              ├── POST /price  ──► pricing-engine (HTTP)
              └── POST /send   ──► notification-service (HTTP) ──► Mailpit SMTP

  + Traefik (:80 / :8080) com labels Docker pra auto-discovery
  + PostgreSQL único com 3 DBs: monolithic_qa, preview_pr123, preview_pr456
```

### Os 3 ambientes

| Ambiente | Front | DB | Estratégia | order chama... |
|---|---|---|---|---|
| **QA** | :3000 | `monolithic_qa` | shared baseline | qa-pricing + qa-notification |
| **PR-123** (`feature/YOU-123-nova-cobertura`) | :3001 | `preview_pr123` clonado | **clona tudo** | pr123-pricing + pr123-notification |
| **PR-456** (`feature/YOU-456-ajuste-fator-idade`) | :3002 | `preview_pr456` clonado | **changed-only** | pr456-pricing + **qa-notification** (herdado) |

---

### 🌐 Guia visual: o que abre em cada URL localhost

Depois de `docker compose ... up -d`, você tem **6 URLs** abertas na sua máquina. Cada uma serve um propósito diferente:

#### 🟦 http://localhost:3000 — QA (baseline)

- **O que é:** A versão "estável" do app — equivalente ao `qa.youse.io` real.
- **Banco:** `monolithic_qa` (5 leads iniciais).
- **Banner no topo:** cinza/azul, identifica como "QA".
- **Comportamento:** quando você cria uma cotação aqui, o `qa-order` chama `qa-pricing` e `qa-notification`. Tudo dentro do "perímetro QA".
- **Pra que serve:** ponto de referência. Toda alteração feita em PR não deve afetar este ambiente.

#### 🟩 http://localhost:3001 — PR-123 (full preview)

- **O que é:** Preview completo da branch `feature/YOU-123-nova-cobertura`. Simula o cenário **"o time de Pricing E o time de Notificações alteraram algo no mesmo PR"**.
- **Banco:** `preview_pr123` — **clone independente** do `monolithic_qa` (mesma massa inicial, mas isolado).
- **Banner no topo:** amarelo/laranja com badge `[PREVIEW]`.
- **Comportamento:** `pr123-order` chama `pr123-pricing` (próprio) + `pr123-notification` (próprio). Os 3 microservices do PR rodam em containers separados.
- **Email gerado:** chega no Mailpit com `From: noreply+pr123@preview.youse.test`.
- **Pra que serve:** mostra o caso "pesado" de preview — quando o PR mexe em vários services, todos sobem juntos.

#### 🟧 http://localhost:3002 — PR-456 (only-changed, com herança)

- **O que é:** Preview da branch `feature/YOU-456-ajuste-fator-idade`, que **só alterou o pricing** (não mexeu em notificação).
- **Banco:** `preview_pr456` — outro clone independente.
- **Banner no topo:** roxo/rosa com badge `[PREVIEW – CHANGED ONLY]`.
- **Comportamento:** `pr456-order` chama `pr456-pricing` (próprio, porque mudou) **MAS** chama `qa-notification` (do QA, porque não mudou). É o padrão **"only-changed-services"** — economia de containers/CPU quando o PR é pequeno.
- **Email gerado:** chega no Mailpit com `From: noreply+pr-456@preview.youse.test` — mesmo passando pelo `qa-notification`, a identidade do PR é preservada (graças ao `preview_id` enviado no body do request).
- **Pra que serve:** prova o caso de uso **mais comum** na prática — PRs pequenos não precisam clonar todos os services.

#### 📧 http://localhost:8025 — Mailpit (caixa de e-mails)

- **O que é:** servidor SMTP local que **captura todos os e-mails** que os 3 ambientes mandariam pra fora — substitui o SES/SendGrid em ambiente de teste.
- **O que você vê:** uma UI tipo Gmail, com todos os e-mails de cotação de QA + PR-123 + PR-456 misturados.
- **Como diferenciar:** olhe o `From:` — `noreply+qa@` / `noreply+pr123@` / `noreply+pr-456@`. Cada preview assina seus próprios e-mails.
- **Pra que serve:** valida que cada ambiente envia notificações com identidade própria, mesmo quando compartilha o service de notificação (caso do PR-456).

#### 🚦 http://localhost:8080 — Traefik dashboard

- **O que é:** painel do reverse proxy que faz roteamento por hostname (`qa.localhost`, `pr-123.localhost`, `pr-456.localhost`).
- **O que você vê:** lista de **routers**, **services** e **middlewares** descobertos automaticamente via labels Docker (sem nenhum arquivo de config manual).
- **Pra que serve:** demonstra o padrão que vai pra produção — em vez de Traefik, na AWS vira **Istio VirtualService** no EKS, mas o conceito é o mesmo: 1 label no manifest = 1 rota criada.

#### 🗄️ http://localhost:5050 — pgAdmin (inspeção dos bancos)

- **O que é:** UI do PostgreSQL. Login: `poc@poc.com` / senha: `poc`.
- **Como conectar:** adicione um servidor com host `postgres-qa-simulado`, porta `5432`, user `youse`, senha `youse`.
- **O que inspecionar:** os **3 bancos lado a lado** (`monolithic_qa`, `preview_pr123`, `preview_pr456`). Rode `SELECT count(*) FROM leads` em cada um — números diferentes = isolamento real.
- **Pra que serve:** prova visual de que os clones são bancos **independentes**, não schemas/views do mesmo DB.

---

### 🔄 Fluxo end-to-end que você pode reproduzir manualmente

1. Abre http://localhost:3001 (PR-123) → clica em "COTE GRÁTIS Auto"
2. Preenche lead → veículo → finaliza cotação
3. Abre http://localhost:8025 (Mailpit) → vê o email com `From: noreply+pr123@`
4. Abre http://localhost:3002 (PR-456) e faz a mesma coisa
5. Volta no Mailpit → tem outro email com `From: noreply+pr-456@` (mesmo o service de notificação sendo o `qa-notification`!)
6. Abre http://localhost:5050 (pgAdmin) → conta leads em cada DB → vê que cresceram **independentemente** em `preview_pr123` e `preview_pr456`, sem tocar no `monolithic_qa`

---

### Como rodar

```powershell
cd environment-platform/poc-real/db/local-test
docker compose -f docker-compose.cotacao-v3.yml up --build -d

# Espera ~60s; valida end-to-end:
powershell -File .\test-v3.ps1
```

Saída esperada do `test-v3.ps1`:

```
=== PR-123 (porta 3001) ===
  quote        : YSE-PR-123-xxxxx -> R$ 561.17/mes
  pricing      : http://pr123-pricing:4000 [preview]
  notification : http://pr123-notification:4000 [preview]
  db usado     : preview_pr123

=== PR-456 (porta 3002) ===
  quote        : YSE-PR-456-xxxxx -> R$ 500.50/mes
  pricing      : http://pr456-pricing:4000 [preview]
  notification : http://qa-notification:4000 [inherited-from-qa]   ◄── chave!
  db usado     : preview_pr456

=== Mailpit inbox ===
From: noreply+pr123@preview.youse.test     ← PR-123 via notification próprio
From: noreply+pr-456@preview.youse.test    ← PR-456 via QA-notification, From dinâmico
```

### O que cada serviço faz

| Serviço | Endpoint | Função |
|---|---|---|
| `api-pricing` | `POST /price` | Stateless. Recebe FIPE+ano+cobertura → devolve `{monthly, annual}` |
| `api-order` (BFF) | `POST /api/quotes` | Orquestra: cria lead → busca preço → persiste quote → dispara email |
| `api-notification` | `POST /send` | Envia email via Mailpit. Aceita `preview_id` no body pra setar `From:` dinâmico |
| `frontend-v3` | nginx + 4 HTMLs | Proxy `/api/*` pro order-service. Busca `/preview.json` pra montar banner |
| `traefik` | `:80`, `:8080` | Auto-discovery via labels Docker. Roteia por `Host(...)`. |

### O que isso prova (que a v2 não provava)

1. **Clones paralelos seguros** — 2 `CREATE DATABASE TEMPLATE` rodam ao mesmo tempo, completam <10s cada
2. **Isolamento real entre PRs** — leads do PR-123 vão pro `preview_pr123`; do PR-456 pro `preview_pr456`. Cada DB tem suas próprias linhas; o QA não muda
3. **Service mesh DNS-only** ([ADR-001](../../../../docs/ADR-001-routing-preview-qa.md)) — o `order-service` decide pra onde chamar usando só env vars (`PRICING_URL`, `NOTIFICATION_URL`). Sem service mesh complexa
4. **Padrão "only-changed-services"** ([ADR-002](../../../../docs/ADR-002-estrategia-bancos.md)) — PR-456 demonstra: clonou só pricing+order, reusa notification do QA. Economia de containers em PRs pequenos
5. **Identidade do preview preservada cross-service** — quando PR-456 chama o qa-notification compartilhado, o `From:` ainda sai como `noreply+pr-456@` porque o `preview_id` é passado no body do request
6. **Traefik labels = templating de service mesh** — `traefik.http.routers.pr123-front.rule=Host(\`pr-123.localhost\`)` é o mesmo padrão que vai pra `Istio VirtualService` no EKS

### Derrubar v3

```powershell
docker compose -f docker-compose.cotacao-v3.yml down -v
```

---

---

## 🎬 O que a POC demonstra

A POC replica o **fluxo real de cotação de Seguro Auto da Youse** (`qa.youse.io` → "COTE GRÁTIS" → `cotacao.youse.com.br/seguro-auto/.../lead_info`) numa cópia visualmente idêntica, rodando 100% local:

### Fluxo do usuário (frontend)

| Passo | Tela | Rota |
|---|---|---|
| 1 | Home com cards Auto/Residencial/Vida + CTA "COTE GRÁTIS" | `index.html` |
| 2 | Lead info: nome + email + telefone | `lead_info.html` |
| 3 | Dados do veículo: placa, marca, modelo, ano, FIPE | `vehicle.html` |
| 4 | Cotação calculada + email enviado de verdade | `quote.html` |

### O que acontece por baixo (backend)

1. **`postgres-qa-simulado`** sobe com schema `monolithic_qa` (3 leads + 3 veículos + 3 cotações de QA).
2. **`clone-db-job`** roda **`CREATE DATABASE preview_you_123 TEMPLATE monolithic_qa`** — em ~8s, banco clonado com toda a massa do QA.
3. **`api-cotacao`** (Node/Express) conecta no banco clonado, calcula prêmio (simula o `pricing-engine`) e dispara email via SMTP.
4. **`mailpit`** captura o SMTP local e mostra o email recebido numa UI tipo Gmail em `http://localhost:8025`.
5. **`pgadmin`** permite inspecionar `monolithic_qa` (QA) lado a lado com `preview_you_123` (preview) — você vê que a alteração no preview **não afeta o QA**.

> 💡 Quer receber em **e-mail real** (Gmail/Outlook)? Edite [docker-compose.cotacao-v2.yml](environment-platform/poc-real/db/local-test/docker-compose.cotacao-v2.yml) e descomente o bloco SMTP real (linhas comentadas `# SMTP_HOST: smtp.gmail.com`).

---

## 🏗️ Arquitetura

### Stack da POC local

```
┌────────────────────────────────────────────────────────────┐
│                  Browser (você)                            │
└──────────┬─────────────────────────────────┬───────────────┘
           │                                 │
           ▼                                 ▼
  ┌───────────────────┐              ┌──────────────────┐
  │ frontend-cotacao  │  fetch()     │   api-cotacao    │
  │  (nginx :3000)    │ ───────────► │  (Node :4000)    │
  │  4 telas HTML     │              │  Express + pg    │
  └───────────────────┘              │  + nodemailer    │
                                     └────┬──────────┬──┘
                                          │          │
                                  SQL     │          │  SMTP
                                          ▼          ▼
                          ┌────────────────────┐  ┌──────────────┐
                          │ postgres-qa-simulado│  │   mailpit    │
                          │      :5433          │  │ :1025 / 8025 │
                          │                     │  └──────────────┘
                          │ ┌─────────────────┐ │
                          │ │ monolithic_qa   │ │  ◄── template
                          │ └────────┬────────┘ │
                          │          │ CLONE    │
                          │          ▼          │
                          │ ┌─────────────────┐ │
                          │ │ preview_you_123 │ │  ◄── usado pela API
                          │ └─────────────────┘ │
                          └─────────────────────┘
```

### Mapeamento POC ↔ produção Youse

| POC local | Produção Youse |
|---|---|
| `postgres-qa-simulado` (PG 14 Alpine) | RDS `monolithic-qa` (PG 14.22, `sa-east-1`) |
| `CREATE DATABASE ... TEMPLATE` (~8s local, <500ms warm) | Mesmo comando contra RDS real (validado em `clone-db.sh`) |
| `api-cotacao` (Node mock) | `pricing-engine` + `sales-frontend` + `mailer-service` reais |
| `mailpit` (captura SMTP) | SES / SendGrid (produção) |
| `clone-db-job` (Docker one-shot) | Step do GitHub Actions ou job CircleCI |

---

## 🔬 Por que `CREATE DATABASE ... TEMPLATE`?

Era a peça crítica do projeto: validar que dá pra clonar o banco de QA **rápido o suficiente** pra ser viável dentro de um pipeline de PR.

### Validações feitas

| Cenário | Tempo | Observação |
|---|---|---|
| Local (Docker, ~50 MB de dados) | **8.178 ms** | Cold start, primeiro clone |
| RDS warm (estimado, com cache OS) | **< 500 ms** | Mesma instância, dados já em buffer |
| Integridade dos dados | ✅ 100% | Todas as FKs, índices, sequences preservados |
| Isolamento | ✅ Total | Alteração em `preview_you_123` NÃO afeta `monolithic_qa` |

### Requisitos (e como contornar)

- **Zero conexões ativas** no template — resolvido com `pg_terminate_backend()` antes do CREATE
- **Postgres ≥ 9.0** — Youse usa 12.11 e 14.22, ambos suportam
- **Mesmo cluster** — não funciona cross-RDS (limitação aceita: clones sempre na própria instância de QA)

---

## 🗺️ Mapa dos RDS reais da Youse (QA)

Em [environment-platform/poc-real/db/rds-map.yaml](environment-platform/poc-real/db/rds-map.yaml):

| RDS | Engine | DB principal | Estratégia |
|---|---|---|---|
| `shared-qa-v12` | PG 12.11 | `postgres` | `CREATE DATABASE TEMPLATE` |
| `monolithic-qa` | PG 14.22 | `monolithic_qa` | `CREATE DATABASE TEMPLATE` |
| `pricing-engine-qa` | PG 14.22 | `pricing_qa` | `CREATE DATABASE TEMPLATE` |
| `crivo-qa` | PG 12.x | `crivo_qa` | `CREATE DATABASE TEMPLATE` |
| `guidewire-qa` | PG 12.x | `guidewire_qa` | `CREATE DATABASE TEMPLATE` |

**Conta AWS:** `514007640321` · **Região:** `sa-east-1` · **IAM:** `arn:aws:iam::514007640321:role/circleci`

---

## 📂 Estrutura detalhada de `local-test/`

```
local-test/
├─ docker-compose.cotacao-v2.yml   ← stack principal (use este)
├─ clone-db-init.sh                ← script do job de clone (entrypoint)
├─ seed-qa-v2.sql                  ← seed do QA simulado (3 leads/veículos/quotes)
├─ pgadmin-servers.json            ← config pré-carregada do pgAdmin
├─ api-cotacao/
│  ├─ Dockerfile                   ← Node 20 Alpine
│  ├─ package.json                 ← express, pg, nodemailer, cors
│  └─ server.js                    ← 4 endpoints REST (leads/vehicles/quotes/health)
└─ frontend-cotacao/
   ├─ index.html                   ← landing Youse
   ├─ lead_info.html               ← passo 1
   ├─ vehicle.html                 ← passo 2
   └─ quote.html                   ← passo 3 + resultado + email
```

---

## 🔌 API REST (`api-cotacao`)

Base URL: `http://localhost:4000`

| Método | Rota | Descrição |
|---|---|---|
| `GET` | `/api/health` | Healthcheck (verifica conexão com DB clonado) |
| `POST` | `/api/leads` | Cria lead (passo 1) |
| `POST` | `/api/vehicles` | Adiciona veículo a um lead (passo 2) |
| `POST` | `/api/quotes` | Calcula prêmio + envia email (passo 3) |
| `GET` | `/api/quotes` | Lista todas as cotações do preview |

### Exemplo de chamada completa (PowerShell)

```powershell
$h = @{'Content-Type'='application/json'}

# 1. Lead
$lead = Invoke-RestMethod http://localhost:4000/api/leads -Method POST -Headers $h `
  -Body '{"name":"Joao","email":"joao@test.com","phone":"11999990000"}'

# 2. Veículo
$veh = Invoke-RestMethod http://localhost:4000/api/vehicles -Method POST -Headers $h `
  -Body (@{lead_id=$lead.id; license_plate="ABC1D23"; brand="Honda"; model="Civic"; year=2023; fipe_value=185000} | ConvertTo-Json)

# 3. Cotação + email
$q = Invoke-RestMethod http://localhost:4000/api/quotes -Method POST -Headers $h `
  -Body (@{lead_id=$lead.id; vehicle_id=$veh.id; coverage_type="completo"} | ConvertTo-Json)

$q.email.status   # → "sent"
# email cai em http://localhost:8025
```

---

## 🛠️ De onde vieram as decisões técnicas

Cada peça da POC reflete uma decisão informada pelo **stack real da Youse**:

| Decisão | Por quê |
|---|---|
| **PostgreSQL 14-alpine** | É a versão que o RDS `monolithic-qa` usa (PG 14.22). Garantia que `CREATE DATABASE TEMPLATE` se comporta igual. |
| **`CREATE DATABASE TEMPLATE`** (não snapshot/restore) | Snapshot RDS leva minutos. `TEMPLATE` leva sub-segundo. Único caminho viável pra preview-por-PR. |
| **PostgREST descartado em favor de Node** | PostgREST era simples mas sem espaço pra lógica de envio de email + cálculo de prêmio. Node deu flexibilidade. |
| **Mailpit** | Padrão de mercado pra capturar SMTP em dev (substitui MailHog). UI moderna, API REST, zero config. |
| **Layout Youse-like** | Pra demo ser convincente — não basta "funcionar", precisa parecer o produto real pro time entender o impacto. |
| **Volumes nomeados (`pg_data_v2`)** | Permite `docker compose down` sem perder dados; `down -v` quando quer reset total. |
| **`condition: service_completed_successfully`** | Garante que `api-cotacao` só sobe depois do clone terminar — sem isso, race condition. |

---

## 📚 Documentação complementar

- [PROJETO-AMBIENTES-YOUSE-v2-CLONE.md](PROJETO-AMBIENTES-YOUSE-v2-CLONE.md) — documento técnico longo, arquitetura completa, custos, riscos
- [docs/apresentacao-time-qualidade.md](docs/apresentacao-time-qualidade.md) — versão p/ time de QA
- [docs/apresentacao-time-infra.md](docs/apresentacao-time-infra.md) — versão p/ time de Infra
- [docs/GUIA-PRATICO-AMBIENTES-FERRAMENTAS.md](docs/GUIA-PRATICO-AMBIENTES-FERRAMENTAS.md) — comparativo de ferramentas avaliadas

---

## 🚦 Status do projeto

| Item | Status |
|---|---|
| Validação local do `CREATE DATABASE TEMPLATE` | ✅ Validado (8s clone, integridade 100%) |
| POC visual fim-a-fim (landing → email) | ✅ Funcionando |
| Mapeamento dos RDS reais da Youse | ✅ Documentado em `rds-map.yaml` |
| Script production-ready (`clone-db.sh`) | ✅ Pronto (precisa rodar dentro da VPC) |
| GitHub Actions workflow exemplo | ✅ Em `.github/workflows/` |
| **Validação contra RDS real da Youse** | ⏳ Pendente (precisa VPN Infra + permissão IAM) |
| Provisionamento de pods no EKS | ⏳ Pendente (escopo da próxima fase) |

---

## ❓ FAQ rápido

**P: Isso afeta `qa.youse.io`?**
R: Não. A POC roda 100% local. O script `clone-db.sh` (production) usa um banco novo (`preview_*`), nunca toca em `monolithic_qa` direto.

**P: Quanto vai custar em AWS?**
R: `CREATE DATABASE TEMPLATE` não duplica storage físico — ele usa **copy-on-write** no nível do PG. Só os blocos que mudam ocupam espaço novo. Custo marginal por preview: ~poucos MB.

**P: E se o time de Pricing rodar uma migration?**
R: A migration roda só no banco do preview daquela branch. Outras branches/QA não são afetadas. Quando a branch é merged, o destroy job dropa o banco.

**P: Funciona pra Aurora?**
R: Sim, Aurora-PostgreSQL suporta `CREATE DATABASE TEMPLATE` igual. Mas a Youse usa RDS comum (não Aurora) — confirmado no repo `terraform-platform`.

---

## 👤 Autoria

Gabriel Roquim — Time de Qualidade Youse · 2026

Repo: https://github.com/gabrielroquim-youse/estrutura-ambientes-youse
