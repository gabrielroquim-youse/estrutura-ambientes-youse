#!/usr/bin/env bash
# Valida estrutura do golden-seed localmente (sem Infra)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEED_DIR="$(dirname "$SCRIPT_DIR")"

echo "Validando golden-seed em: $SEED_DIR"

[[ -f "$SEED_DIR/version.yaml" ]] || { echo "ERRO: version.yaml ausente"; exit 1; }

MANIFESTS="$SEED_DIR/manifests"
if [[ -d "$MANIFESTS" ]]; then
  count=$(find "$MANIFESTS" -name '*.json' -o -name '*.yaml' | wc -l)
  echo "OK: $count manifest(s) encontrado(s)"
else
  echo "AVISO: pasta manifests/ vazia ou ausente"
fi

# Valida JSON básico (requer jq se disponível)
if command -v jq &>/dev/null; then
  for f in "$MANIFESTS"/*.json; do
    [[ -f "$f" ]] || continue
    jq empty "$f" && echo "OK: JSON válido — $(basename "$f")"
  done
fi

echo ""
echo "validate-seed: PASSED (validação local)"
