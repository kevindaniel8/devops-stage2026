#!/bin/bash
# Script de health check pour PostgreSQL distant
# À placer sur la VM PostgreSQL pour surveillance par Beszel

# Variables d'environnement (peuvent être surchargées)
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_NAME="${POSTGRES_DB:-postgres}"

echo "=== PostgreSQL Health Check ==="
echo "Host: $DB_HOST:$DB_PORT"
echo "User: $DB_USER"
echo "Database: $DB_NAME"

# Test 1: Vérification si PostgreSQL est accessible
echo -n "1. Connexion PostgreSQL... "
if pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER -q; then
    echo "✅ OK"
else
    echo "❌ FAILED - PostgreSQL n'est pas accessible"
    exit 1
fi

# Test 2: Vérification de la base de données
echo -n "2. Test de requête... "
if PGPASSWORD=${POSTGRES_PASSWORD:-} psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1;" -q -t > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ FAILED - Impossible d'exécuter une requête"
    exit 1
fi

# Test 3: Vérification des connexions actives
echo -n "3. Connexions actives... "
CONNECTIONS=$(PGPASSWORD=${POSTGRES_PASSWORD:-} psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT count(*) FROM pg_stat_activity;" -q -t 2>/dev/null | tr -d ' ')
if [ $? -eq 0 ]; then
    echo "✅ $CONNECTIONS connexions actives"
else
    echo "❌ FAILED - Impossible de compter les connexions"
fi

# Test 4: Vérification de l'espace disque
echo -n "4. Espace disque... "
if command -v psql >/dev/null 2>&1; then
    DB_SIZE=$(PGPASSWORD=${POSTGRES_PASSWORD:-} psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" -q -t 2>/dev/null | tr -d ' ')
    if [ $? -eq 0 ] && [ -n "$DB_SIZE" ]; then
        echo "✅ Taille base: $DB_SIZE"
    else
        echo "⚠️  Impossible de récupérer la taille"
    fi
else
    echo "⚠️  psql non disponible"
fi

echo "=== Health Check Completed ==="
exit 0
