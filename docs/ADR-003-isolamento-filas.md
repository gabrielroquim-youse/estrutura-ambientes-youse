# ADR-003: Isolamento de Filas/SQS por Preview

> **Status:** 🟡 Proposto · aguardando validação com Infra
> **Data:** 2026-06-24
> **Autor:** Gabriel Roquim
> **Relacionado:** [ADR-001 — Routing](ADR-001-routing-preview-qa.md) · [ADR-002 — Bancos](ADR-002-estrategia-bancos.md)

---

## 📌 Resumo

Quando um preview publica uma mensagem em SQS/SNS que **outros serviços do QA consomem**, o consumer do QA pode "roubar" a mensagem ou causar side effects (envio de email, charge real). Este ADR define como isolar mensageria.

**Recomendação:** **Filas com sufixo por preview** (`<fila-original>-pr-<N>`) criadas/destruídas com o ciclo de vida do preview.

---

## 🎯 Contexto

### Cenário concreto

`pricing-engine` (preview) publica `quote.created` no SNS. Subscribers:
- `order-service` (QA) → consome, dispara fluxo de venda
- `notification-service` (QA) → envia **email real** pro cliente
- `analytics-pipeline` → registra evento em data lake

Se o preview não estiver isolado:
- ❌ Email real é enviado pra cliente real
- ❌ Charge é tentado em cartão real
- ❌ Métricas de QA são poluídas

---

## 🗳️ Opções consideradas

### Opção A — Filas dedicadas por preview ⭐

**Como funciona:** Pipeline cria `cotacao-criada-pr-123`, `cotacao-criada-pr-124` etc. Preview publica/consome só nas suas filas. Ao destruir o preview, filas são deletadas.

```yaml
# Exemplo de provisionamento dinâmico
- name: create-preview-queues
  run: |
    aws sqs create-queue --queue-name cotacao-criada-pr-${{ env.PR_NUMBER }}
    aws sqs create-queue --queue-name policy-emitida-pr-${{ env.PR_NUMBER }}
```

**✅ Pros:**
- Isolamento total — preview não interfere em QA
- Sem efeitos colaterais externos (emails/charges)
- Modelo previsível, fácil de auditar
- Ciclo de vida acoplado ao preview (create/destroy)

**❌ Contras:**
- Provisionamento extra no setup (vários segundos por preview)
- Custo SQS por fila (mas é centavos por preview)
- Aplicações precisam saber qual fila usar (via env var)

---

### Opção B — Filtros por message attribute

**Como funciona:** Mensagens carregam atributo `preview_id`. Consumers filtram via SNS subscription filter policy ou lendo o atributo no SQS.

**✅ Pros:**
- Reusa filas existentes — nada novo a provisionar
- Modelo simples conceitualmente

**❌ Contras:**
- **TODOS os consumers** precisam ser preview-aware (refator grande)
- Mensagem do preview ainda **trafega** pelas filas de QA — risco de processamento acidental
- Filtros SQS são limitados (não tão flexíveis quanto routing rules)

---

### Opção C — Reutilizar filas + mock consumers críticos

**Como funciona:** Preview usa filas do QA, mas serviços com side effects externos (notification, charge) são **mockados** no preview.

**✅ Pros:**
- Nada extra a provisionar
- Side effects controlados

**❌ Contras:**
- Mensagens do preview são consumidas pelos serviços do QA (incluindo `order-service`)
- Estado do QA fica inconsistente (cotação criada por preview vira venda em QA)
- Não é isolamento real

---

## 🎯 Recomendação

### Fase 1 (piloto): **Opção A (filas dedicadas)**

**Por quê:**
- Isolamento é requisito não-negociável (especialmente p/ filas que disparam side effects: email, charge)
- Provisionamento dinâmico é trivial via AWS SDK/CLI
- Custo é desprezível (poucos centavos por preview)

**Setup proposto:**

1. **Inventariar** filas/tópicos que cada serviço Tier 1 usa (via `terraform-platform` ou consulta SDK)
2. **Pipeline cria** filas com sufixo no provisioning do preview
3. **Aplicações leem nome da fila via env var** (já é boas práticas; validar nos repos)
4. **Pipeline destroi** filas no teardown do preview
5. **Subscriptions SNS:** se preview usa SNS, criar subscription dedicada com filter `preview_id = pr-123`

**Convenção de naming:**
```
QA:       cotacao-criada-qa
Preview:  cotacao-criada-pr-<NUMBER>
```

**Side effects perigosos:**
- `notification-service` precisa de **flag de ambiente** pra usar `mailpit` em vez de SES real (igual já fizemos na POC)
- `charge-service` precisa de **gateway sandbox** quando rodando em preview

---

## 🗺️ Inventário inicial de side effects a mockar

| Side effect | Serviço Youse | Estratégia em preview |
|---|---|---|
| Email transacional | `messaging-gateway` / `notification` | Apontar SMTP pra Mailpit interno (já validado na POC) |
| Charge real | `charge-service` | Apontar pra sandbox do gateway (Cielo? Stone? a confirmar) |
| Webhook pra parceiros | `partner-api` / `messaging-gateway` | Apontar pra Mockoon/Beeceptor interno |
| Documentos assinados | `documents` (DocuSign?) | Modo `dev` da SDK do provider |
| Push notifications | `mob-flutter` backend | Desabilitar via env |

---

## 📋 Validações necessárias

1. **Time de plataforma:** quais filas existem? Existe registry/catálogo?
2. **Time de cada serviço Tier 1:** quais subscriptions críticas? Quais dependem de filas externas?
3. **Custos:** estimar custo mensal de filas extras assumindo X PRs/dia (provavelmente trivial)
4. **Confirmar:** SNS+SQS é o padrão, ou tem filas SQS standalone?

---

## 🔗 Referências

- [AWS SQS pricing](https://aws.amazon.com/sqs/pricing/) — filas custam ~$0.40 por milhão de requests
- [SNS Subscription Filter Policies](https://docs.aws.amazon.com/sns/latest/dg/sns-message-filtering.html)
- [POC Mailpit demonstration](../environment-platform/poc-real/db/local-test/docker-compose.cotacao-v2.yml) — exemplo de mock SMTP local
