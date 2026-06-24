#!/usr/bin/env bash
# =============================================================================
# detect-changed-services.sh
#
# Compara a branch atual com a base (main/master) e descobre quais
# serviços foram alterados. Saída: lista de nomes de serviço, um por linha.
#
# Uso:
#   ./detect-changed-services.sh                    # compara com origin/main
#   ./detect-changed-services.sh origin/master      # compara com outra base
#   CHANGED_SERVICES=$(./detect-changed-services.sh)
#
# Lógica:
#   - Cada serviço é um diretório raiz do repo monorepo (ou um repo próprio)
#   - O mapa SERVICES define: "prefixo de path no git diff" → "nome do serviço"
#   - Arquivos que não mapeiam para nenhum serviço são ignorados
# =============================================================================

set -euo pipefail

BASE_REF="${1:-origin/main}"
CURRENT_REF="${2:-HEAD}"

# ---------------------------------------------------------------------------
# MAPA: prefixo do path alterado → nome do serviço
# Adapte para a estrutura de repos da Youse.
#
# Em repos separados (1 repo por serviço), o prefixo é sempre "." e você
# usa o nome do repo como serviço (veja modo SINGLE_REPO abaixo).
# ---------------------------------------------------------------------------
declare -A SERVICE_MAP=(
  ["sales-frontend/"]="sales-frontend"
  ["order-service/"]="order-service"
  ["policy-service/"]="policy-service"
  ["payment-service/"]="payment-service"
  ["notification-service/"]="notification-service"
  ["youse-app/"]="youse-app"
  # Adicione mais serviços conforme a estrutura de repos da Youse
)

# Modo: "monorepo" ou "single" (1 repo = 1 serviço)
REPO_MODE="${REPO_MODE:-monorepo}"
SINGLE_SERVICE_NAME="${SINGLE_SERVICE_NAME:-}"  # usado quando REPO_MODE=single

# ---------------------------------------------------------------------------
# Detecta quais arquivos mudaram entre base e branch atual
# ---------------------------------------------------------------------------
echo "▶ Comparando $BASE_REF...$CURRENT_REF" >&2
CHANGED_FILES=$(git diff --name-only "$BASE_REF"..."$CURRENT_REF" 2>/dev/null || \
                git diff --name-only "$BASE_REF" "$CURRENT_REF" 2>/dev/null || \
                echo "")

if [[ -z "$CHANGED_FILES" ]]; then
  echo "⚠ Nenhum arquivo alterado detectado." >&2
  exit 0
fi

echo "▶ Arquivos alterados:" >&2
echo "$CHANGED_FILES" | sed 's/^/   /' >&2
echo "" >&2

# ---------------------------------------------------------------------------
# Modo single: repo inteiro = 1 serviço (repos separados da Youse)
# ---------------------------------------------------------------------------
if [[ "$REPO_MODE" == "single" ]]; then
  if [[ -z "$SINGLE_SERVICE_NAME" ]]; then
    # Tenta pegar o nome da pasta atual como nome do serviço
    SINGLE_SERVICE_NAME=$(basename "$PWD")
  fi
  echo "$SINGLE_SERVICE_NAME"
  echo "▶ Modo single-repo: serviço detectado = $SINGLE_SERVICE_NAME" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Modo monorepo: mapeia paths para serviços
# ---------------------------------------------------------------------------
declare -A DETECTED=()

while IFS= read -r file; do
  matched=false
  for prefix in "${!SERVICE_MAP[@]}"; do
    if [[ "$file" == "$prefix"* ]]; then
      service="${SERVICE_MAP[$prefix]}"
      DETECTED["$service"]=1
      matched=true
      break
    fi
  done
  if [[ "$matched" == false ]]; then
    echo "  (ignorado — sem serviço mapeado): $file" >&2
  fi
done <<< "$CHANGED_FILES"

if [[ ${#DETECTED[@]} -eq 0 ]]; then
  echo "⚠ Nenhum serviço mapeado para os arquivos alterados." >&2
  exit 0
fi

echo "▶ Serviços detectados:" >&2
for svc in "${!DETECTED[@]}"; do
  echo "   ✓ $svc" >&2
  echo "$svc"
done
