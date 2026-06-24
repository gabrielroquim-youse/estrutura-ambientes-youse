#!/usr/bin/env bash
# =============================================================================
# test-clone-local.sh
#
# POC LOCAL — Valida o conceito CREATE DATABASE ... TEMPLATE
# Simula o que acontecera no RDS de QA da Youse.
#
# Sequencia:
#   1. Confirma que monolithic_qa existe com massa de dados
#   2. Clona via CREATE DATABASE TEMPLATE (mesmo comando do RDS real)
#   3. Mostra que o clone tem os MESMOS dados
#   4. Insere dado no clone e prova que NAO afeta o original
#   5. Mostra como destruir o clone
#
# Uso:
#   docker compose -f docker-compose.local-test.yml up -d
#   ./test-clone-local.sh
# =============================================================================

set -euo pipefail

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONTAINER="poc-qa-simulado"
DB_USER="youse"
TEMPLATE_DB="monolithic_qa"
PREVIEW_DB="preview_you_123"

# Helper para rodar psql dentro do container
psql_exec() {
    docker exec -e PGPASSWORD=poc_local_only "$CONTAINER" \
        psql -U "$DB_USER" -d postgres -tAc "$1"
}

psql_exec_db() {
    local db="$1"
    local sql="$2"
    docker exec -e PGPASSWORD=poc_local_only "$CONTAINER" \
        psql -U "$DB_USER" -d "$db" -tAc "$sql"
}

# ---------------------------------------------------------------------------
# 0. Container esta rodando?
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "  POC LOCAL — Clone via CREATE DATABASE TEMPLATE"
echo "=============================================="
echo ""

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo -e "${RED}ERRO: Container '$CONTAINER' nao esta rodando.${NC}"
    echo ""
    echo "Inicie com:"
    echo "  docker compose -f docker-compose.local-test.yml up -d"
    exit 1
fi

# Aguarda banco ficar pronto
echo "▶ Aguardando PostgreSQL ficar pronto..."
for i in {1..20}; do
    if docker exec "$CONTAINER" pg_isready -U "$DB_USER" -d "$TEMPLATE_DB" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Pronto${NC}"
        break
    fi
    sleep 1
done

# ---------------------------------------------------------------------------
# 1. Verificar massa de dados no banco "QA"
# ---------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[1/5] Verificando massa de dados em '$TEMPLATE_DB' (simula QA)...${NC}"

USERS_COUNT=$(psql_exec_db "$TEMPLATE_DB" "SELECT COUNT(*) FROM users;")
POLICIES_COUNT=$(psql_exec_db "$TEMPLATE_DB" "SELECT COUNT(*) FROM policies;")
ORDERS_COUNT=$(psql_exec_db "$TEMPLATE_DB" "SELECT COUNT(*) FROM orders;")

echo "  Banco: $TEMPLATE_DB"
echo "  users:    $USERS_COUNT registros"
echo "  policies: $POLICIES_COUNT registros"
echo "  orders:   $ORDERS_COUNT registros"

if [[ "$USERS_COUNT" -lt 5 ]]; then
    echo -e "${RED}ERRO: Massa de dados nao foi carregada. Reinicie o compose com -v.${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓ Massa de dados OK${NC}"

# ---------------------------------------------------------------------------
# 2. Cleanup de teste anterior (idempotente)
# ---------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[2/5] Limpando teste anterior (se existir)...${NC}"

EXISTS=$(psql_exec "SELECT 1 FROM pg_database WHERE datname = '$PREVIEW_DB';")
if [[ "$EXISTS" == "1" ]]; then
    echo "  Removendo '$PREVIEW_DB' anterior..."
    psql_exec "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$PREVIEW_DB' AND pid <> pg_backend_pid();" >/dev/null
    psql_exec "DROP DATABASE $PREVIEW_DB;" >/dev/null
fi
echo -e "  ${GREEN}✓ Limpo${NC}"

# ---------------------------------------------------------------------------
# 3. CLONAR via CREATE DATABASE TEMPLATE (o coracao da POC)
# ---------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[3/5] Clonando '$TEMPLATE_DB' → '$PREVIEW_DB' ...${NC}"
echo "  Comando: CREATE DATABASE $PREVIEW_DB TEMPLATE $TEMPLATE_DB;"

START=$(date +%s%N)

# Encerra conexoes ativas no template (PostgreSQL exige 0 conexoes)
psql_exec "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$TEMPLATE_DB' AND pid <> pg_backend_pid();" >/dev/null

# CLONE — comando real, identico ao que rodara no RDS de QA da Youse
psql_exec "CREATE DATABASE $PREVIEW_DB TEMPLATE $TEMPLATE_DB;" >/dev/null

END=$(date +%s%N)
ELAPSED_MS=$(( (END - START) / 1000000 ))

echo -e "  ${GREEN}✓ Clone criado em ${ELAPSED_MS}ms${NC}"

# ---------------------------------------------------------------------------
# 4. Provar que o clone tem os mesmos dados
# ---------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[4/5] Verificando que o clone tem a MESMA massa de dados...${NC}"

CLONE_USERS=$(psql_exec_db "$PREVIEW_DB" "SELECT COUNT(*) FROM users;")
CLONE_POLICIES=$(psql_exec_db "$PREVIEW_DB" "SELECT COUNT(*) FROM policies;")
CLONE_ORDERS=$(psql_exec_db "$PREVIEW_DB" "SELECT COUNT(*) FROM orders;")

echo "  Banco: $PREVIEW_DB (clone)"
echo "  users:    $CLONE_USERS registros  (original: $USERS_COUNT)"
echo "  policies: $CLONE_POLICIES registros  (original: $POLICIES_COUNT)"
echo "  orders:   $CLONE_ORDERS registros  (original: $ORDERS_COUNT)"

if [[ "$CLONE_USERS" == "$USERS_COUNT" && "$CLONE_POLICIES" == "$POLICIES_COUNT" ]]; then
    echo -e "  ${GREEN}✓ Massa de dados clonada com sucesso${NC}"
else
    echo -e "  ${RED}✗ Massa divergiu — investigar${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# 5. Provar isolamento — mexer no clone NAO afeta o original
# ---------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[5/5] Testando isolamento (dev pode sujar dados sem afetar QA)...${NC}"

# Dev simula testar nova cotacao na branch
psql_exec_db "$PREVIEW_DB" "INSERT INTO users (cpf, name, email) VALUES ('999.999.999-99', 'Dev Teste Branch', 'dev.branch@youse.test');" >/dev/null
psql_exec_db "$PREVIEW_DB" "INSERT INTO orders (user_id, status, total) VALUES (1, 'test-branch', 9999.99);" >/dev/null

# Conta de novo
CLONE_USERS_AFTER=$(psql_exec_db "$PREVIEW_DB" "SELECT COUNT(*) FROM users;")
ORIG_USERS_AFTER=$(psql_exec_db "$TEMPLATE_DB" "SELECT COUNT(*) FROM users;")

echo "  Inseri 1 user e 1 order NO CLONE ($PREVIEW_DB)"
echo "  users no clone:    $CLONE_USERS_AFTER  (era $CLONE_USERS)"
echo "  users no original: $ORIG_USERS_AFTER  (era $USERS_COUNT)"

if [[ "$CLONE_USERS_AFTER" == "$((CLONE_USERS + 1))" && "$ORIG_USERS_AFTER" == "$USERS_COUNT" ]]; then
    echo -e "  ${GREEN}✓ Isolamento confirmado — original intacto${NC}"
else
    echo -e "  ${RED}✗ Isolamento falhou${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Resumo
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo -e "  ${GREEN}POC VALIDADA${NC}"
echo "=============================================="
echo ""
echo "Provamos que:"
echo "  • CREATE DATABASE TEMPLATE funciona em PostgreSQL ${ELAPSED_MS}ms"
echo "  • Clone tem TODA a massa de dados do banco origem"
echo "  • Dev pode modificar o clone sem afetar o original (isolamento)"
echo ""
echo "No RDS real da Youse (monolithic / pricing-engine / shared-qa-v12)"
echo "o comando e o MESMO. So muda o host/credencial."
echo ""
echo "Inspecionar manualmente:"
echo "  docker exec -it $CONTAINER psql -U $DB_USER $PREVIEW_DB"
echo ""
echo "Destruir tudo:"
echo "  docker compose -f docker-compose.local-test.yml down -v"
echo ""
