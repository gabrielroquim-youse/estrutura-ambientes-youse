# ADR-002: Estratégia de Banco para Serviços Herdados

> **Status:** 🟡 Proposto · aguardando validação com Infra/DBA
> **Data:** 2026-06-24
> **Autor:** Gabriel Roquim
> **Relacionado:** [ADR-001 — Routing](ADR-001-routing-preview-qa.md)

---

## 📌 Resumo

Quando um PR só altera **alguns** microsserviços, os demais ficam "herdados" do QA. Mas e o **banco de dados**? Cada serviço (que tem seu próprio RDS) precisa de clone? Ou apenas os alterados?

**Recomendação:** **só os serviços alterados** ganham clone do seu banco. Demais continuam apontando pro banco do QA — em **modo read-write** com guardrails.

---

## 🎯 Contexto

A Youse tem **5+ RDS distintos** em QA (validado em `terraform-platform`):

| RDS | DB | Engine | Serviços que usam |
|---|---|---|---|
| `monolithic-qa` | `monolithic_qa` | PG 14.22 | monolito + diversos serviços |
| `shared-qa-v12` | `postgres` | PG 12.11 | múltiplos serviços (auth shared) |
| `pricing-engine-qa` | `pricing_qa` | PG 14.22 | `pricing-engine` |
| `crivo-qa` | `crivo_qa` | PG 12.x | `crivo` (risk-acceptance?) |
| `guidewire-qa` | `guidewire_qa` | PG 12.x | Guidewire stack |

Cada `CREATE DATABASE TEMPLATE` cria um clone no **mesmo RDS** (limitação técnica: não cross-instance).

---

## 🗳️ Opções consideradas

### Opção A — Clone DB para TODOS os serviços do preview

**Como funciona:** Toda PR clona **todos os bancos** dos serviços envolvidos no fluxo (mesmo os herdados).

**✅ Pros:**
- Isolamento absoluto — preview não toca em QA
- Migrations destrutivas são seguras
- Testes E2E completos sem efeitos cruzados

**❌ Contras:**
- Custo de connection pool — 5+ bancos novos por preview, x N PRs simultâneas
- Tempo de setup maior (cada clone ~8s no warm, mas multiplicado)
- Complexidade no pipeline (precisa saber TODAS as dependências)
- Serviços herdados precisam ser **reconfigurados** pra apontar pro banco do preview (env var)

---

### Opção B — Clone DB SÓ pros serviços alterados ⭐

**Como funciona:** PR mexeu no `pricing-engine` → clona só `pricing-engine-qa`. Demais serviços herdados continuam usando `monolithic_qa`, `shared-qa-v12` etc. **do próprio QA**.

**✅ Pros:**
- Custo mínimo
- Setup rápido (1-2 clones por preview)
- Pipeline simples (mesma lógica do `detect-changed-services.sh`)
- Aproveita o fato de que **a maioria das PRs mexe em 1-2 serviços**

**❌ Contras:**
- Risco: se preview executa lógica que escreve em banco herdado, pode contaminar QA
- Migrations destrutivas: serviço alterado pode esperar schema diferente em banco compartilhado
- Limita testes E2E que dependem de gravação cruzada

---

### Opção C — Híbrida: Tier 1 clona, Tier 2 read-only no QA

**Como funciona:** Serviços que **frequentemente recebem PRs** (Tier 1: pricing-engine, order-service, monolithic) sempre ganham clone. Os demais (Tier 2: documents, c360, etc.) ficam herdados do QA, **mas em modo read-only** pra o preview.

**✅ Pros:**
- Balanço entre custo e isolamento
- Preview pode "ler" do QA pra ter contexto, sem corromper

**❌ Contras:**
- Aplicações Rails normalmente não suportam read-only fácil (precisa criar role PG dedicada)
- Complexidade extra de gestão de permissões

---

## 🎯 Recomendação

### Fase 1 (piloto): **Opção B (só serviços alterados)**

**Por quê:**
- Maioria absoluta das PRs mexe em 1-2 serviços → caso de uso mais comum
- Pipeline mais simples → tempo até "primeiro preview" menor
- Custo previsível em RDS

**Guardrails necessários:**

1. **Documentação clara** dizendo: "preview escreve em banco compartilhado. NÃO rode migrations destrutivas em PRs que mexem em tabelas compartilhadas."
2. **Lint no CI** detectando migrations `DROP COLUMN`/`DROP TABLE` em PRs que serão preview-enabled (alerta, não bloqueio)
3. **TTL automático** de previews — máximo 7 dias, depois auto-destroy
4. **Convenção:** preview escreve com prefix (`preview_pr123_` ou `__preview_`) em chaves naturais, pra facilitar limpeza

### Fase 2 (3+ serviços, casos complexos): **Avaliar Opção A (clone tudo)**

**Quando reavaliar:**
- Quando QA reportar "preview X corrompeu dados do QA"
- Quando frequência de PRs cruzadas aumentar
- Quando custo de RDS for justificável

---

## 🗺️ Mapeamento "qual banco clonar" por serviço Tier 1

| Serviço alterado | RDS clonado |
|---|---|
| `pricing-engine` | `pricing-engine-qa` (PG 14.22) |
| `policy-service` | provavelmente `monolithic-qa` ou shared — **a validar** |
| `order-service` | provavelmente `monolithic-qa` — **a validar** |
| `billing-cloud` | a validar |
| `claims-service` | a validar |
| `crivo` (risk-acceptance) | `crivo-qa` (PG 12) |

> ⚠️ **Pré-requisito da Fase 1:** mapear cada serviço Tier 1 → seu RDS. Pode ser feito olhando os secrets `qa/rds/admin/<rds>` que cada serviço lê.

---

## 📋 Validações necessárias

1. **DBA Youse:** ok com `CREATE DATABASE TEMPLATE` rodando dinamicamente nos RDS de QA?
2. **Plataforma:** quotas de databases por RDS — quantos clones simultâneos os RDS suportam?
3. **SRE:** precisa monitoring específico pra alertar sobre "preview travado consumindo conexão"?
4. **Time pricing-engine:** quais migrations recentes seriam destrutivas em ambiente compartilhado?

---

## 🔗 Referências

- [PostgreSQL CREATE DATABASE TEMPLATE](https://www.postgresql.org/docs/current/manage-ag-templatedbs.html)
- [POC validada localmente](../environment-platform/poc-real/db/local-test/README.md) — 8s clone, integridade 100%
- [`environment-platform/poc-real/db/clone-db.sh`](../environment-platform/poc-real/db/clone-db.sh) — script production-ready
- [`environment-platform/poc-real/db/rds-map.yaml`](../environment-platform/poc-real/db/rds-map.yaml) — mapa dos RDS reais
