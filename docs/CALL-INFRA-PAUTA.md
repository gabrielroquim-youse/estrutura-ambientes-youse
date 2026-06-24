# 🎤 Pauta — Call com Infra/DevOps

> **Objetivo:** Validar a viabilidade técnica e definir os próximos passos para implementar o piloto de **ambientes efêmeros por branch** ("1 PR = 1 preview environment") na Youse.

---

## 📋 Pré-requisitos (enviar antes da call)

1. **Repo da POC:** https://github.com/gabrielroquim-youse/estrutura-ambientes-youse
2. **Inventário dos microsserviços:** [`docs/INVENTARIO-MICROSSERVICOS-YOUSE.md`](INVENTARIO-MICROSSERVICOS-YOUSE.md)
3. **Documento técnico longo:** [`PROJETO-AMBIENTES-YOUSE-v2-CLONE.md`](../PROJETO-AMBIENTES-YOUSE-v2-CLONE.md)

> 💡 Pedir ao time pra **rodar a POC localmente** (`docker compose up` — 5 min) antes da call. Quem rodou entende muito mais rápido.

---

## ⏱️ Estrutura sugerida (30 min)

| Tempo | Bloco | Quem fala |
|---|---|---|
| 0-5 min | Contexto + Demo rápida | Gabriel |
| 5-10 min | O que está validado vs o que falta | Gabriel |
| 10-25 min | **3 decisões abertas** (discussão) | Todos |
| 25-30 min | Próximos passos + responsáveis | Todos |

---

## 🎯 As 3 decisões que precisam ser tomadas

### Decisão 1 — Routing preview ↔ QA

**O problema:** Quando um PR sobe um pod novo do `pricing-engine` no namespace `preview-pr-123`, como o `monolithic` (que continua no QA) sabe que tem que chamar o pricing-engine **do preview**, não o do QA?

**Opções:**

| Opção | Como funciona | Pros | Contras |
|---|---|---|---|
| **A. Istio + header routing** | Header `X-Preview: pr-123` direciona pra namespace certo | Mais flexível, observability nativa | Complexidade alta, curva de aprendizado |
| **B. Linkerd + service profile** | Service profile por namespace | Mais leve que Istio | Menos features de roteamento |
| **C. DNS-only (CoreDNS + namespace)** | `pricing-engine.preview-pr-123.svc.cluster.local` | Simples, sem service mesh | Aplicação precisa saber o namespace |
| **D. Híbrida — Ingress dedicado** | NGINX/Traefik com subdomínio por PR | Funciona p/ frontend, simples | Não resolve service-to-service interno |

**🎙️ Perguntar pra Infra:**
- O EKS já tem service mesh? (`gitops-kubernetes-addons` sugere que sim)
- Qual a preferência da equipe?
- Quanto trabalho extra cada opção implica?

---

### Decisão 2 — Estratégia de banco para serviços herdados

**O problema:** Se `pricing-engine` (preview) escreve numa tabela compartilhada, mas `order-service` (herdado do QA) lê dessa mesma tabela... eles precisam apontar pro mesmo banco?

**Opções:**

| Opção | Comportamento | Pros | Contras |
|---|---|---|---|
| **A. Cada serviço com seu próprio banco clonado** | Cada microsserviço Tier 1 → 1 clone. Preview tem seu schema completo. | Isolamento total. Testes E2E plenos. | Mais bancos = mais conexões |
| **B. Read-only no QA, writes no preview** | Serviços herdados só leem QA. Writes vão pro preview. | Mais simples. Menos custo. | Limita testes que dependem de escrita cruzada |
| **C. Apenas serviços alterados ganham preview DB** | Detecta `git diff` → só clona DB dos serviços que mudaram. | Custo mínimo. | Pode quebrar se PR só mexe em código que assume schema novo |

**🎙️ Perguntar pra Infra:**
- Quantos RDS distintos a Youse tem em QA? (vi 5+ no `terraform-platform`)
- Política de conexões: cada microsserviço tem connection pool dedicado?
- Algum serviço usa transações cross-database?

---

### Decisão 3 — Filas/SQS/eventos por preview

**O problema:** Se `pricing-engine` (preview) publica mensagem no SQS `cotacao-criada-qa`, o `order-service` do QA vai consumir e processar — "roubando" do preview ou causando efeitos colaterais.

**Opções:**

| Opção | Comportamento | Pros | Contras |
|---|---|---|---|
| **A. Filas por preview (`cotacao-criada-pr123`)** | Cada preview cria suas filas no setup | Isolamento total | Trabalho extra de provisionamento |
| **B. Filtros por message attribute** | Mensagens carregam `preview_id`, consumers filtram | Reusa filas existentes | Consumers precisam ser preview-aware |
| **C. Tópicos SNS + subscrições filtradas** | Pub/Sub com filtros de subscrição | Padrão AWS suporta nativo | Refatoração se Youse usa SQS direto |

**🎙️ Perguntar pra Infra:**
- Padrão atual: SQS direto ou SNS → SQS?
- Há filas críticas com side effects (envio de email, charge)? Como mockar/desabilitar em preview?

---

## ✅ Output esperado da call

- [ ] **Decisão 1** (routing): opção escolhida + responsável por desenhar
- [ ] **Decisão 2** (banco): estratégia definida pra Fase 1
- [ ] **Decisão 3** (filas): padrão acordado
- [ ] **Serviço-piloto** confirmado (sugestão: `pricing-engine`)
- [ ] **Data alvo** pro primeiro preview funcional
- [ ] **Responsáveis** por cada frente:
  - DB clone job no pipeline → ?
  - Deploy automation → ?
  - Routing config → ?
  - Documentação → Gabriel

---

## 🙋 Stakeholders sugeridos

| Quem | Por quê |
|---|---|
| **Infra/DevOps lead** | Decisão de service mesh / routing |
| **DBA / Platform** | Aprovação do clone DB no RDS real |
| **Tech Lead do `pricing-engine`** | Piloto Tier 1 |
| **QA Lead** | Beneficiário direto, valida casos de uso |
| **Gabriel (Qualidade)** | Apresenta + facilita |

---

## 📎 Material complementar pra mandar antes

1. Link do repo + README (já tudo documentado)
2. Print do fluxo rodando (3 telas) ou Loom curto (60s) gravado
3. Inventário dos microsserviços ([`INVENTARIO-MICROSSERVICOS-YOUSE.md`](INVENTARIO-MICROSSERVICOS-YOUSE.md))
4. Esta pauta

---

## 💬 Modelo de convite (Google Calendar / Slack)

```
📅 Call: Ambientes Efêmeros por Branch — Validação Técnica com Infra

⏱️ 30 min
🎯 Objetivo: tomar 3 decisões técnicas + alinhar piloto

📋 Pauta:
  1. Contexto + demo rápida (5 min)
  2. O que está validado / o que falta (5 min)
  3. Decisões abertas (15 min):
     a) Routing preview ↔ QA
     b) Estratégia de banco p/ serviços herdados
     c) Filas/SQS isoladas
  4. Próximos passos (5 min)

📎 Pré-leitura (15 min antes):
  - Repo + README: https://github.com/gabrielroquim-youse/estrutura-ambientes-youse
  - Inventário microsserviços: docs/INVENTARIO-MICROSSERVICOS-YOUSE.md
  - Ideal: rodar a POC local (3 comandos, 5 min)
```
