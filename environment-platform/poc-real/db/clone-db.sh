#!/usr/bin/env bash
# =============================================================================
# clone-db.sh — Clona banco(s) de QA para um preview isolado
#
# Usa CREATE DATABASE ... TEMPLATE do PostgreSQL para criar um clone
# instantâneo (segundos) dentro do mesmo RDS de QA — sem custo extra.
#
# Credenciais via AWS Secrets Manager (padrão real da Youse):
#   qa/rds/admin/shared-qa-v12
#   qa/rds/admin/monolithic
#   qa/rds/admin/pricing-engine
#   qa/rds/admin/<service>
#
# Uso:
#   ./clone-db.sh <preview-name> <rds-name> [<db-template>]
#
# Exemplos:
#   ./clone-db.sh you-123 shared-qa-v12
#   ./clone-db.sh you-123 monolithic monolithic_qa
#   ./clone-db.sh you-123 pricing-engine pricing_qa
#
# Pré-requisitos:
#   - aws cli configurado (ou rodando com a role circleci do CircleCI/GHA)
#   - psql disponível no PATH
#   - Acesso de rede ao RDS de QA (VPN GlobalProtect ou runner no VPC)
# =============================================================================

set -euo pipefail

PREVIEW_NAME="${1:-}"
RDS_NAME="${2:-}"         # ex.: shared-qa-v12, monolithic, pricing-engine
DB_TEMPLATE="${3:-}"      # ex.: monolithic_qa  (default: detecta abaixo)

AWS_REGION="${AWS_REGION:-sa-east-1}"

# ---------------------------------------------------------------------------
# Validação de entrada
# ---------------------------------------------------------------------------
if [[ -z "$PREVIEW_NAME" || -z "$RDS_NAME" ]]; then
  echo "Uso: $0 <preview-name> <rds-name> [<db-template>]"
  echo ""
  echo "RDS disponíveis no QA da Youse:"
  echo "  shared-qa-v12    → secret: qa/rds/admin/shared-qa-v12"
  echo "  monolithic       → secret: qa/rds/admin/monolithic"
  echo "  pricing-engine   → secret: qa/rds/admin/pricing-engine"
  echo "  crivo            → secret: qa/rds/admin/crivo"
  echo "  guidewire        → secret: qa/rds/admin/guidewire"
  exit 1
fi

# ---------------------------------------------------------------------------
# Mapa: nome do RDS → nome do banco template (padrão Youse encontrado no repo)
# ---------------------------------------------------------------------------
declare -A DB_DEFAULTS=(
  ["shared-qa-v12"]="postgres"       # db_name = "postgres" (shared RDS)
  ["monolithic"]="monolithic_qa"     # db_name = "monolithic_qa"
  ["pricing-engine"]="pricing_qa"    # db_name = "pricing_qa"
  ["crivo"]="crivo_qa"
  ["guidewire"]="guidewire_qa"
  ["rds-shared-qa-upgraded"]="notifier_qa"
)

if [[ -z "$DB_TEMPLATE" ]]; then
  DB_TEMPLATE="${DB_DEFAULTS[$RDS_NAME]:-${RDS_NAME}_qa}"
fi

# Nome do banco de destino (sanitizado, max 63 chars PostgreSQL)
PREVIEW_SAFE=$(echo "$PREVIEW_NAME" | sed 's/[^a-zA-Z0-9_]/_/g' | cut -c1-40)
TARGET_DB="preview_${PREVIEW_SAFE}"

SECRET_ID="qa/rds/admin/${RDS_NAME}"

echo "=============================================="
echo "  CLONE DE BANCO — POC Youse"
echo "=============================================="
echo "Preview:    $PREVIEW_NAME"
echo "RDS:        $RDS_NAME"
echo "Template:   $DB_TEMPLATE"
echo "Destino:    $TARGET_DB"
echo "Secret:     $SECRET_ID"
echo "Região:     $AWS_REGION"
echo ""

# ---------------------------------------------------------------------------
# 1. Buscar credenciais no Secrets Manager
#    Padrão real: {"admin_username": "...", "admin_password": "..."}
# ---------------------------------------------------------------------------
echo "[1/5] Buscando credenciais em $SECRET_ID ..."

SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ID" \
  --region "$AWS_REGION" \
  --query 'SecretString' \
  --output text 2>/dev/null) || {
  echo "ERRO: Não foi possível acessar o secret '$SECRET_ID'."
  echo "      Verifique se a role tem permissão secretsmanager:GetSecretValue"
  exit 1
}

DB_USER=$(echo "$SECRET_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('admin_username', d.get('username', '')))")
DB_PASS=$(echo "$SECRET_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('admin_password', d.get('password', '')))")
DB_HOST=$(echo "$SECRET_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('host', ''))" 2>/dev/null || true)

if [[ -z "$DB_USER" || -z "$DB_PASS" ]]; then
  echo "ERRO: Secret não contém 'admin_username'/'admin_password'"
  echo "      Conteúdo recebido (sem senha): $(echo "$SECRET_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); d.pop('admin_password',''); d.pop('password',''); print(d)")"
  exit 1
fi

# Host do RDS: tenta do secret, depois monta o padrão AWS
if [[ -z "$DB_HOST" ]]; then
  # Padrão de hostname RDS da Youse (baseado nos identifiers encontrados)
  # Ex.: shared-qa-v12.xxxx.sa-east-1.rds.amazonaws.com
  DB_HOST="${RDS_NAME}.$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_NAME" \
    --region "$AWS_REGION" \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text 2>/dev/null || echo 'RDS_HOST_NOT_FOUND')"
fi

echo "  Host: $DB_HOST"
echo "  User: $DB_USER"
echo "  ✓ Credenciais obtidas"

# ---------------------------------------------------------------------------
# 2. Verificar se banco template existe
# ---------------------------------------------------------------------------
echo ""
echo "[2/5] Verificando banco template '$DB_TEMPLATE' ..."

export PGPASSWORD="$DB_PASS"

DB_EXISTS=$(psql \
  -h "$DB_HOST" \
  -U "$DB_USER" \
  -p 5432 \
  -d postgres \
  -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB_TEMPLATE';" 2>/dev/null || echo "")

if [[ "$DB_EXISTS" != "1" ]]; then
  echo "ERRO: Banco template '$DB_TEMPLATE' não encontrado em $DB_HOST"
  echo "      Bancos disponíveis:"
  psql -h "$DB_HOST" -U "$DB_USER" -p 5432 -d postgres \
    -c "\l" 2>/dev/null || true
  exit 1
fi
echo "  ✓ Template '$DB_TEMPLATE' encontrado"

# ---------------------------------------------------------------------------
# 3. Verificar se preview já existe (idempotente)
# ---------------------------------------------------------------------------
echo ""
echo "[3/5] Verificando se preview já existe ..."

PREVIEW_EXISTS=$(psql \
  -h "$DB_HOST" \
  -U "$DB_USER" \
  -p 5432 \
  -d postgres \
  -tAc "SELECT 1 FROM pg_database WHERE datname = '$TARGET_DB';" 2>/dev/null || echo "")

if [[ "$PREVIEW_EXISTS" == "1" ]]; then
  echo "  ⚠ Banco '$TARGET_DB' já existe — pulando criação (idempotente)"
  echo ""
  echo "✓ Banco preview já disponível: $TARGET_DB"
  echo "  Host: $DB_HOST"
  echo "  User: $DB_USER"
  echo "  Porta: 5432"
  unset PGPASSWORD
  exit 0
fi
echo "  ✓ Banco novo — prosseguindo com clone"

# ---------------------------------------------------------------------------
# 4. Encerrar conexões ativas no template antes de clonar
#    (PostgreSQL exige 0 conexões no banco template)
# ---------------------------------------------------------------------------
echo ""
echo "[4/5] Encerrando conexões ativas em '$DB_TEMPLATE' ..."

psql \
  -h "$DB_HOST" \
  -U "$DB_USER" \
  -p 5432 \
  -d postgres \
  -c "SELECT pg_terminate_backend(pid)
      FROM pg_stat_activity
      WHERE datname = '$DB_TEMPLATE'
        AND pid <> pg_backend_pid();" \
  -q 2>/dev/null || true

echo "  ✓ Conexões encerradas"

# ---------------------------------------------------------------------------
# 5. Clonar o banco — CREATE DATABASE ... TEMPLATE
#    Instantâneo (<5s para bancos de até ~10GB no mesmo RDS)
# ---------------------------------------------------------------------------
echo ""
echo "[5/5] Clonando '$DB_TEMPLATE' → '$TARGET_DB' ..."

START_TIME=$(date +%s)

psql \
  -h "$DB_HOST" \
  -U "$DB_USER" \
  -p 5432 \
  -d postgres \
  -c "CREATE DATABASE \"$TARGET_DB\" TEMPLATE \"$DB_TEMPLATE\";" \
  -q

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

unset PGPASSWORD

echo ""
echo "=============================================="
echo "  ✓ CLONE CONCLUÍDO em ${ELAPSED}s"
echo "=============================================="
echo ""
echo "  Banco:     $TARGET_DB"
echo "  Host:      $DB_HOST"
echo "  Porta:     5432"
echo "  Usuário:   $DB_USER"
echo "  Origem:    $DB_TEMPLATE (snapshot atual do QA)"
echo ""
echo "  DATABASE_URL: postgresql://$DB_USER:***@$DB_HOST:5432/$TARGET_DB"
echo ""
echo "Destroy: ./destroy-db.sh $PREVIEW_NAME $RDS_NAME"
echo "----------------------------------------------"

# Exporta para uso em scripts encadeados
echo "export PREVIEW_DB_NAME=$TARGET_DB" >> /tmp/preview-${PREVIEW_NAME}.env
echo "export PREVIEW_DB_HOST=$DB_HOST" >> /tmp/preview-${PREVIEW_NAME}.env
echo "export PREVIEW_DB_USER=$DB_USER" >> /tmp/preview-${PREVIEW_NAME}.env
