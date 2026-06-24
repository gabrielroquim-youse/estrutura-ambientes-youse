#!/usr/bin/env bash
# POC — simula teardown de clone
# Uso: ./simulate-destroy.sh you-123

set -euo pipefail

NAME="${1:?Informe o nome do ambiente (ex: you-123)}"

echo "=============================================="
echo "  SIMULADOR DE DESTROY (POC — sem Infra)"
echo "=============================================="
echo ""
echo "[1/5] Remover DNS ................. SIMULADO (you-123.preview.youse.io)"
echo "[2/5] Helm uninstall .............. SIMULADO (namespace preview-$NAME)"
echo "[3/5] Remover namespace K8s ....... SIMULADO"
echo "[4/5] Remover DB clone ............ SIMULADO"
echo "[5/5] Liberar conta golden-seed ... SIMULADO"
echo ""
echo "Ambiente $NAME: Terminated (simulado)"
