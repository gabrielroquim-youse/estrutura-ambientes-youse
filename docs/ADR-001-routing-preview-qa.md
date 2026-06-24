# ADR-001: Estratégia de Roteamento entre Preview e QA

> **Status:** 🟡 Proposto · aguardando validação com Infra
> **Data:** 2026-06-24
> **Autor:** Gabriel Roquim
> **Contexto:** POC de ambientes efêmeros por branch

---

## 📌 Resumo (TL;DR)

Quando um PR cria um ambiente preview com **apenas alguns microsserviços alterados**, os demais serviços precisam ser "herdados" do QA. Este ADR define **como o serviço-novo do preview se comunica com os serviços-herdados-do-QA** (e vice-versa).

**Recomendação:** começar com **DNS-only por namespace** (opção C) por simplicidade. Migrar para **Istio com header routing** (opção A) apenas se Fase 2 demandar.

---

## 🎯 Contexto

### Cenário concreto

PR `#123` mexe **só no `pricing-engine`**. O fluxo de cotação real chama:

```
sales-frontend → order-service → pricing-engine → risk-acceptance → policy-service
                                       ↑
                              SÓ ESTE precisa subir novo
```

Os outros 4 serviços continuam rodando no QA compartilhado.

### Problema técnico

1. Quando `order-service` (no QA) precisa chamar `pricing-engine`, como ele encontra o pod **do preview** e não o do QA?
2. Quando `pricing-engine` (preview) precisa chamar `risk-acceptance`, como ele cai no pod **do QA** (herdado)?

Sem uma estratégia clara, OU o preview vira ilha desconectada, OU mensagens cruzam ambientes causando estado inconsistente.

---

## 🗳️ Opções consideradas

### Opção A — Istio + header-based routing

**Como funciona:** Service mesh injeta sidecars Envoy. Requests carregam header `X-Preview-Id: pr-123`. VirtualService roteia baseado no header.

```yaml
# Exemplo de VirtualService
- match:
    - headers:
        x-preview-id:
          exact: pr-123
  route:
    - destination:
        host: pricing-engine
        subset: preview-pr-123
- route:
    - destination:
        host: pricing-engine
        subset: qa
```

**✅ Pros:**
- Roteamento dinâmico sem mudar código da aplicação
- Observability nativa (traces, metrics)
- Permite canary, traffic shift, mirroring (útil pra testes)
- Padrão de mercado pra preview environments

**❌ Contras:**
- Complexidade operacional alta (Istio é conhecidamente complexo)
- Sidecars consomem CPU/memória extra
- Curva de aprendizado pra time
- Aplicações precisam **propagar o header** (W3C Trace Context ou similar)

---

### Opção B — Linkerd + ServiceProfile

**Como funciona:** Service mesh mais leve. Roteamento via ServiceProfile + per-route configs.

**✅ Pros:**
- Mais leve que Istio (sidecars Rust)
- mTLS automático
- UI/observability boas out-of-the-box

**❌ Contras:**
- Menos flexível em roteamento (não tem o equivalente completo do VirtualService)
- Comunidade menor que Istio
- Header routing exige config menos elegante

---

### Opção C — DNS-only (CoreDNS + namespace) ⭐

**Como funciona:** Kubernetes resolve `pricing-engine.preview-pr-123.svc.cluster.local` pro pod do preview, e `pricing-engine.qa.svc.cluster.local` pro pod do QA. Aplicação **decide qual usar** via env var.

```yaml
# No deployment do preview
env:
  - name: PRICING_ENGINE_URL
    value: "http://pricing-engine.preview-pr-123.svc.cluster.local"
  - name: RISK_ACCEPTANCE_URL
    value: "http://risk-acceptance.qa.svc.cluster.local"  # herdado do QA
```

A pipeline de criação do preview popula essas envs baseado em **quais serviços mudaram**:
- Se mudou → aponta pro preview
- Se não mudou → aponta pro QA

**✅ Pros:**
- **Simplíssimo** — usa o que Kubernetes já oferece nativamente
- Zero infraestrutura extra (sem service mesh)
- Funciona com qualquer linguagem
- Debugging trivial (curl funciona)
- Padrão "12-Factor" (config via env)

**❌ Contras:**
- Aplicação precisa ler URLs de env vars (na Youse, parece que já é o padrão pelos repos)
- Sem traffic shift / canary
- Observability cruzada de namespaces precisa ser configurada à parte

---

### Opção D — Ingress dedicado (NGINX/Traefik com subdomínio por PR)

**Como funciona:** Cada PR tem um subdomínio (`pr-123.preview.youse.dev`) que aponta pra um ingress que roteia.

**✅ Pros:**
- Ótimo pra frontends (devs/QA acessam URL pública)
- Simples de implementar

**❌ Contras:**
- **Não resolve** o problema interno (service-to-service)
- Útil só como camada de entrada, precisa ser combinado com A/B/C

---

## 🎯 Recomendação

### Fase 1 (piloto, 1 serviço): **Opção C (DNS-only) + D (Ingress) combinadas**

**Por quê:**
- Piloto vai ter **1 serviço alterado** (`pricing-engine`)
- Não precisa de roteamento dinâmico sofisticado
- Aproveitamos infra Kubernetes existente, sem novo software
- Tempo até "first preview funcionando" cai pela metade

**Setup:**
- Cada preview tem namespace `preview-pr-<N>`
- Pipeline gera `kustomize` overlay que ajusta env vars de URLs
- Ingress (NGINX) cria subdomínio `pr-<N>.preview.youse.dev` apontando pro frontend do preview

### Fase 2 (3+ serviços, casos com matriz complexa): **Avaliar Opção A (Istio)**

**Quando reavaliar:**
- Quando precisar testar 2+ serviços mudados na mesma PR
- Quando aparecer caso de uso de canary/traffic shift
- Quando observability cruzada virar requisito

**Pré-requisito p/ migração futura:** Aplicações já preparadas pra propagar trace headers (W3C ou Zipkin).

---

## 📋 Validações necessárias antes de fechar

1. **Confirmar com Infra:** EKS já tem algum service mesh? (`gitops-kubernetes-addons` sugere ArgoCD, não vi mesh explícito)
2. **Confirmar com time de plataforma:** as aplicações Ruby da Youse já leem URLs de outros serviços via env var? (boas práticas dizem que sim)
3. **Verificar:** existe wildcard DNS `*.preview.youse.dev` disponível? (precisa pra Opção D)

---

## 🔗 Referências

- [Vercel Preview Deployments — Architecture](https://vercel.com/docs/deployments/preview-deployments)
- [Heroku Review Apps](https://devcenter.heroku.com/articles/github-integration-review-apps)
- [Argo Rollouts Header Routing](https://argo-rollouts.readthedocs.io/en/stable/features/traffic-management/)
- [Istio Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
- [Kubernetes DNS for Services](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
