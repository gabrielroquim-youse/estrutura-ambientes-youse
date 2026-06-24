#!/usr/bin/env bash
# POC — simula provisionamento de clone SEM infra Youse
# Uso: ./simulate-clone.sh environment-platform/examples/branch-preview-request.yaml

set -euo pipefail

REQUEST_FILE="${1:-../examples/branch-preview-request.yaml}"

if [[ ! -f "$REQUEST_FILE" ]]; then
  echo "ERRO: arquivo não encontrado: $REQUEST_FILE"
  exit 1
fi

NAME=$(grep -E '^\s*name:' "$REQUEST_FILE" | head -1 | awk '{print $2}')
TEMPLATE=$(grep -E 'sourceTemplate:' "$REQUEST_FILE" | awk '{print $2}')
TTL=$(grep -E '^\s*ttl:' "$REQUEST_FILE" | awk '{print $2}')
HOST=$(grep -E 'hostname:' "$REQUEST_FILE" | awk '{print $2}')

echo "=============================================="
echo "  SIMULADOR DE CLONE (POC — sem Infra)"
echo "=============================================="
echo ""
echo "[1/8] Validar YAML .............. OK"
echo "[2/8] Template origem ........... $TEMPLATE"
echo "[3/8] Criar namespace K8s ....... SIMULADO (preview-$NAME)"
echo "[4/8] Aplicar golden-seed ....... SIMULADO (version em golden-seed/version.yaml)"
echo "[5/8] Helm deploy overlay ....... SIMULADO"
echo "[6/8] Registrar DNS ............. SIMULADO → https://$HOST"
echo "[7/8] validate-seed.sh .......... SIMULADO → OK"
echo "[8/8] Notificar Slack/Jira ...... SIMULADO"
echo ""
echo "Ambiente: $NAME"
echo "URL:      https://$HOST"
echo "TTL:      $TTL"
echo "Status:   Ready (simulado)"
echo ""
echo "Próximo: QA/Dev acessam a URL acima."
echo "Destroy: ./simulate-destroy.sh $NAME"
