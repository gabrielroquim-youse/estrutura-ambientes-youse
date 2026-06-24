#!/usr/bin/env bash
# =============================================================================
# clone-selective.sh
#
# Gera um docker-compose OVERRIDE com SOMENTE os serviços alterados na branch.
# O override substitui a imagem "golden" pela versão da branch do dev.
#
# O resultado é um arquivo /tmp/preview-<name>.override.yml que, combinado com
# docker-compose.golden.yml, sobe:
#   - Serviços da branch: imagem buildada da branch (ou do commit da branch)
#   - Serviços não alterados: herdados do golden (composição docker-compose)
#
# Uso:
#   ./clone-selective.sh <preview-name> "<service1> <service2>"
#
# Exemplo:
#   ./clone-selective.sh you-123 "sales-frontend order-service"
#
# Após rodar:
#   docker compose \
#     -f docker-compose.golden.yml \
#     -f /tmp/preview-you-123.override.yml \
#     up -d sales-frontend order-service
# =============================================================================

set -euo pipefail

PREVIEW_NAME="${1:-you-local}"
CHANGED_SERVICES="${2:-}"  # espaço ou newline separados
BRANCH="${BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')}"
OVERRIDE_FILE="/tmp/preview-${PREVIEW_NAME}.override.yml"

# Registry de imagens — adapte para o ECR da Youse
IMAGE_REGISTRY="${IMAGE_REGISTRY:-123456.dkr.ecr.us-east-1.amazonaws.com}"

echo "=============================================="
echo "  CLONE SELETIVO — $PREVIEW_NAME"
echo "=============================================="
echo "Branch:   $BRANCH"
echo "Serviços: $CHANGED_SERVICES"
echo "Override: $OVERRIDE_FILE"
echo ""

if [[ -z "$CHANGED_SERVICES" ]]; then
  echo "⚠ Nenhum serviço informado. Nada a fazer."
  exit 0
fi

# ---------------------------------------------------------------------------
# Gera o arquivo override com os serviços alterados
# ---------------------------------------------------------------------------
cat > "$OVERRIDE_FILE" << YAML_HEADER
# Override gerado automaticamente por clone-selective.sh
# Preview: $PREVIEW_NAME | Branch: $BRANCH
# NÃO edite manualmente — gerado em $(date -u +"%Y-%m-%dT%H:%M:%SZ")

version: "3.9"

services:
YAML_HEADER

# Para cada serviço alterado, sobrescreve a imagem com a versão da branch
for service in $CHANGED_SERVICES; do
  # Limpa espaços/newlines extras
  service=$(echo "$service" | tr -d '[:space:]')
  [[ -z "$service" ]] && continue

  echo "  ▶ Adicionando override para: $service"

  # Gera tag baseada na branch (sanitiza chars especiais)
  BRANCH_TAG=$(echo "$BRANCH" | sed 's/[^a-zA-Z0-9._-]/-/g' | cut -c1-128)

  cat >> "$OVERRIDE_FILE" << YAML_SERVICE

  $service:
    # Versão da branch sobrescreve o golden template
    image: ${IMAGE_REGISTRY}/${service}:${BRANCH_TAG}
    build:
      # Para POC local: builda a partir do código da branch
      context: ./services/${service}
      dockerfile: Dockerfile
      args:
        NODE_ENV: preview
        BRANCH: "${BRANCH}"
    labels:
      youse.preview.service: "${service}"
      youse.preview.source: "branch"          # <-- diferencia do golden
      youse.preview.branch: "${BRANCH}"
      youse.preview.name: "${PREVIEW_NAME}"
YAML_SERVICE

done

echo ""
echo "✓ Override gerado: $OVERRIDE_FILE"
echo ""
echo "──────────────────────────────────────────────"
echo "COMO USAR:"
echo ""
echo "  # Sobe SOMENTE os serviços alterados + infraestrutura base"
echo "  docker compose \\"
echo "    -f environment-platform/poc-real/docker-compose.golden.yml \\"
echo "    -f $OVERRIDE_FILE \\"
echo "    up -d $CHANGED_SERVICES preview-db integrations-mock"
echo ""
echo "  # Ver o que vai subir (sem subir)"
echo "  docker compose \\"
echo "    -f environment-platform/poc-real/docker-compose.golden.yml \\"
echo "    -f $OVERRIDE_FILE \\"
echo "    config"
echo ""
echo "  # Destroy completo"
echo "  docker compose \\"
echo "    -f environment-platform/poc-real/docker-compose.golden.yml \\"
echo "    -f $OVERRIDE_FILE \\"
echo "    down -v"
echo "──────────────────────────────────────────────"
