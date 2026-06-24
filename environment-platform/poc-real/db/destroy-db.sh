#!/usr/bin/env bash
# =============================================================================
# destroy-db.sh — Remove banco de preview (teardown)
#
# Chamado automaticamente quando:
#   - PR é mergeado
#   - PR é fechado sem merge
#   - TTL de 72h expira
#
# Uso:
#   ./destroy-db.sh <preview-name> <rds-name>
#
# Exemplos:
#   ./destroy-db.sh you-123 shared-qa-v12
#   ./destroy-db.sh you-123 monolithic
# =============================================================================

set -euo pipefail

PREVIEW_NAME="${1:-}"
RDS_NAME="${2:-}"

AWS_REGION="${AWS_REGION:-sa-east-1}"

if [[ -z "$PREVIEW_NAME" || -z "$RDS_NAME" ]]; then
  echo "Uso: $0 <preview-name> <rds-name>"
  exit 1
fi

PREVIEW_SAFE=$(echo "$PREVIEW_NAME" | sed 's/[^a-zA-Z0-9_]/_/g' | cut -c1-40)
TARGET_DB="preview_${PREVIEW_SAFE}"
SECRET_ID="qa/rds/admin/${RDS_NAME}"

echo "=============================================="
echo "  DESTROY DE BANCO — $PREVIEW_NAME"
echo "=============================================="
echo "Banco:  $TARGET_DB"
echo "RDS:    $RDS_NAME"
echo ""

# ---------------------------------------------------------------------------
# 1. Buscar credenciais
# ---------------------------------------------------------------------------
echo "[1/3] Buscando credenciais ..."

SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ID" \
  --region "$AWS_REGION" \
  --query 'SecretString' \
  --output text 2>/dev/null) || {
  echo "ERRO: Secret '$SECRET_ID' não acessível — abortando destroy"
  exit 1
}

DB_USER=$(echo "$SECRET_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('admin_username', d.get('username', '')))")
DB_PASS=$(echo "$SECRET_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('admin_password', d.get('password', '')))")
DB_HOST=$(echo "$SECRET_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('host', ''))" 2>/dev/null || true)

if [[ -z "$DB_HOST" ]]; then
  DB_HOST=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_NAME" \
    --region "$AWS_REGION" \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text 2>/dev/null || echo '')
fi

export PGPASSWORD="$DB_PASS"
echo "  ✓ Credenciais obtidas"

# ---------------------------------------------------------------------------
# 2. Verificar se banco existe (evita erro em destroy duplo)
# ---------------------------------------------------------------------------
echo ""
echo "[2/3] Verificando banco '$TARGET_DB' ..."

DB_EXISTS=$(psql \
  -h "$DB_HOST" -U "$DB_USER" -p 5432 -d postgres \
  -tAc "SELECT 1 FROM pg_database WHERE datname = '$TARGET_DB';" 2>/dev/null || echo "")

if [[ "$DB_EXISTS" != "1" ]]; then
  echo "  ⚠ Banco '$TARGET_DB' não existe — nada a fazer (já destruído ou nunca criado)"
  unset PGPASSWORD
  # Limpa env file se existir
  rm -f "/tmp/preview-${PREVIEW_NAME}.env"
  exit 0
fi
echo "  ✓ Banco encontrado"

# ---------------------------------------------------------------------------
# 3. Encerrar conexões e dropar banco
# ---------------------------------------------------------------------------
echo ""
echo "[3/3] Encerrando conexões e removendo '$TARGET_DB' ..."

# Força disconnect de qualquer conexão aberta no preview
psql \
  -h "$DB_HOST" -U "$DB_USER" -p 5432 -d postgres \
  -c "SELECT pg_terminate_backend(pid)
      FROM pg_stat_activity
      WHERE datname = '$TARGET_DB'
        AND pid <> pg_backend_pid();" \
  -q 2>/dev/null || true

# Drop do banco de preview
psql \
  -h "$DB_HOST" -U "$DB_USER" -p 5432 -d postgres \
  -c "DROP DATABASE IF EXISTS \"$TARGET_DB\";" \
  -q

unset PGPASSWORD

# Limpa arquivos temporários
rm -f "/tmp/preview-${PREVIEW_NAME}.env"
rm -f "/tmp/preview-${PREVIEW_NAME}.override.yml"

echo ""
echo "  ✓ Banco '$TARGET_DB' removido"
echo ""
echo "✓ Destroy concluído: $PREVIEW_NAME"
