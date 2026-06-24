#!/bin/sh
# =============================================================================
# clone-db-init.sh — Script de inicialização do clone (rodado pelo job)
#
# Usado pelo docker-compose.cotacao.yml — passado como volume para o container
# postgres:14-alpine que executa o clone.
#
# Faz:
#   1. Encerra conexões ativas em monolithic_qa
#   2. Verifica se preview_you_123 já existe (idempotente)
#   3. Se não, cria via CREATE DATABASE TEMPLATE
# =============================================================================

set -e

HOST="${PG_HOST:-postgres-qa-simulado}"
USER="${PG_USER:-youse}"
TEMPLATE="${PG_TEMPLATE:-monolithic_qa}"
PREVIEW="${PG_PREVIEW:-preview_you_123}"

echo ""
echo "=============================================="
echo "  CLONE DB JOB"
echo "=============================================="
echo "Host:     $HOST"
echo "User:     $USER"
echo "Template: $TEMPLATE"
echo "Preview:  $PREVIEW"
echo ""

# Aguarda template ficar disponivel (defensivo, healthcheck ja garante)
echo "[1/3] Verificando template '$TEMPLATE'..."
RETRY=0
while [ $RETRY -lt 10 ]; do
  if psql -h "$HOST" -U "$USER" -d postgres -tAc \
       "SELECT 1 FROM pg_database WHERE datname='$TEMPLATE'" 2>/dev/null | grep -q 1; then
    echo "  ✓ Template encontrado"
    break
  fi
  RETRY=$((RETRY + 1))
  echo "  ... aguardando template ($RETRY/10)"
  sleep 2
done

if [ $RETRY -eq 10 ]; then
  echo "  ✗ ERRO: Template '$TEMPLATE' nao encontrado apos 20s"
  exit 1
fi

# Encerra conexoes no template (PostgreSQL exige 0 conexoes para clonar)
echo ""
echo "[2/3] Encerrando conexoes ativas em '$TEMPLATE'..."
psql -h "$HOST" -U "$USER" -d postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$TEMPLATE' AND pid <> pg_backend_pid();" \
  > /dev/null 2>&1 || true
echo "  ✓ OK"

# Verifica se preview ja existe (idempotente)
echo ""
echo "[3/3] Criando clone '$PREVIEW' (idempotente)..."
if psql -h "$HOST" -U "$USER" -d postgres -tAc \
     "SELECT 1 FROM pg_database WHERE datname='$PREVIEW'" 2>/dev/null | grep -q 1; then
  echo "  ⚠ Banco '$PREVIEW' ja existe — pulando criacao"
else
  psql -h "$HOST" -U "$USER" -d postgres -c \
    "CREATE DATABASE $PREVIEW TEMPLATE $TEMPLATE;"
  echo "  ✓ Clone '$PREVIEW' criado a partir de '$TEMPLATE'"
fi

echo ""
echo "✓ JOB CONCLUIDO"
