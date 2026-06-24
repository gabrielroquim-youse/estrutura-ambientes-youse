# POC Real — Ambientes por Clone Seletivo

> **Objetivo:** Demonstrar o fluxo completo onde o dev abre uma branch e o ambiente sobe **somente os serviços que ele alterou**. O resto herda do golden template.

---

## Como funciona

```
Dev faz push em feature/YOU-123
         │
         ▼
GitHub Actions detecta arquivos alterados
  git diff main...HEAD → [sales-frontend/, order-service/]
         │
         ▼
clone-selective.sh gera override
  → sales-frontend: imagem da branch YOU-123
  → order-service:  imagem da branch YOU-123
  → policy-service: HERDADO do golden (não sobe)
  → payment-service: HERDADO do golden (não sobe)
         │
         ▼
docker compose up (SOMENTE os serviços alterados)
  + preview-db (seed idempotente do golden-seed)
  + integrations-mock (WireMock — nunca sandbox prod)
         │
         ▼
GitHub Actions comenta na PR:
  URL: you-123.preview.youse.io
  Serviços: sales-frontend ✅, order-service ✅
  Herdados: policy-service ⬆️, payment-service ⬆️
         │
         ▼
PR mergeia → destroy automático
```

---

## Rodar localmente (sem Infra)

### Pré-requisitos

- `git`, `bash`, `docker`, `docker compose`
- Estar dentro de um repo Git (com `origin/main` acessível)

### Passo 1 — Detectar o que mudou na sua branch

```bash
# Na raiz do repo (ou de um repo de serviço da Youse)
./environment-platform/poc-real/detect-changed-services.sh
```

Saída esperada (exemplo):
```
▶ Comparando origin/main...HEAD
▶ Arquivos alterados:
   sales-frontend/src/pages/cotacao.tsx
   order-service/src/handlers/create-order.ts
▶ Serviços detectados:
   ✓ sales-frontend
   ✓ order-service
```

### Passo 2 — Gerar o override de clone seletivo

```bash
./environment-platform/poc-real/clone-selective.sh you-123 "sales-frontend order-service"
```

Isso gera `/tmp/preview-you-123.override.yml` com apenas os serviços da branch.

### Passo 3 — Validar o compose (sem subir)

```bash
docker compose \
  -f environment-platform/poc-real/docker-compose.golden.yml \
  -f /tmp/preview-you-123.override.yml \
  config
```

Mostra o compose final — você verá:
- `sales-frontend`: imagem da branch
- `order-service`: imagem da branch
- `policy-service`: imagem do golden (não sobescrita)
- `payment-service`: imagem do golden (não sobescrita)

### Passo 4 — Subir o ambiente (somente serviços alterados)

```bash
docker compose \
  -f environment-platform/poc-real/docker-compose.golden.yml \
  -f /tmp/preview-you-123.override.yml \
  up -d sales-frontend order-service preview-db integrations-mock
```

### Passo 5 — Destroy

```bash
docker compose \
  -f environment-platform/poc-real/docker-compose.golden.yml \
  -f /tmp/preview-you-123.override.yml \
  down -v
```

---

## Rodar via GitHub Actions (automático)

1. Faça fork ou push neste repo
2. Abra uma PR para `main`
3. O workflow [preview-environment.yml](../../.github/workflows/preview-environment.yml) roda automaticamente
4. Veja o comentário na PR com os serviços detectados e a URL do preview

---

## Adaptar para repos reais da Youse

### Para repos separados (1 repo = 1 serviço)

No `detect-changed-services.sh`, configure:

```bash
REPO_MODE=single SINGLE_SERVICE_NAME=sales-frontend ./detect-changed-services.sh
```

Ou exporte no GitHub Actions:
```yaml
env:
  REPO_MODE: single
  SINGLE_SERVICE_NAME: ${{ github.event.repository.name }}
```

### Para monorepo

Edite o `SERVICE_MAP` em `detect-changed-services.sh`:

```bash
declare -A SERVICE_MAP=(
  ["sales-frontend/"]="sales-frontend"
  ["order-service/"]="order-service"
  ["policy-service/"]="policy-service"
  # ... adicione os serviços da Youse
)
```

### Imagens reais (ECR)

No `clone-selective.sh`, configure `IMAGE_REGISTRY`:

```bash
export IMAGE_REGISTRY="123456.dkr.ecr.us-east-1.amazonaws.com"
```

---

## Ferramentas da POC vs. Produção

| POC (agora) | Produção (depois, com Infra) |
|---|---|
| `git diff` detecta mudanças | Webhook GitHub → Control Plane |
| `docker compose` sobe serviços | EKS namespace + Helm overlay |
| `/tmp/*.override.yml` | CRD `EphemeralEnvironment` no K8s |
| `WireMock` mockando integrações | Sandbox real das integrações |
| `localhost` | `you-123.preview.youse.io` (Route53) |
| Seed via script | RDS snapshot + seed script |

O **conceito é o mesmo** — só a infraestrutura de execução muda.

---

## Arquivos desta POC

```
poc-real/
├── detect-changed-services.sh    # detecta serviços pelo git diff
├── clone-selective.sh            # gera override com serviços da branch
├── docker-compose.golden.yml     # template base (todos os serviços, versão golden)
└── README.md                     # este arquivo

.github/workflows/
└── preview-environment.yml       # GitHub Actions: abre PR → provisiona → fecha → destroy
```
