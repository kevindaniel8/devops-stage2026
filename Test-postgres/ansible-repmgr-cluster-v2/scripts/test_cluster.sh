#!/bin/bash

# Script de test du cluster PostgreSQL repmgr
# ==========================================

set -e

echo "🧪 Test du cluster PostgreSQL repmgr"
echo "================================="

# Variables
MASTER_IP="192.168.56.21"
REPLICA_IP="192.168.56.22"
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"postgres"}
REPMR_PASSWORD=${REPMR_PASSWORD:-"repmgr_password"}

echo "📊 Configuration :"
echo "   Master: $MASTER_IP"
echo "   Replica: $REPLICA_IP"
echo ""

# Test de connexion au master
echo "🔍 Test de connexion au master..."
if PGPASSWORD=$POSTGRES_PASSWORD psql -h $MASTER_IP -U postgres -d postgres -c "SELECT version();" > /dev/null 2>&1; then
    echo "✅ Master accessible"
else
    echo "❌ Master inaccessible"
    exit 1
fi

# Test de connexion au replica
echo "🔍 Test de connexion au replica..."
if PGPASSWORD=$POSTGRES_PASSWORD psql -h $REPLICA_IP -U postgres -d postgres -c "SELECT version();" > /dev/null 2>&1; then
    echo "✅ Replica accessible"
else
    echo "❌ Replica inaccessible"
    exit 1
fi

# Test du cluster repmgr
echo "🔍 Test du cluster repmgr..."
if PGPASSWORD=$REPMR_PASSWORD ssh -o StrictHostKeyChecking=no postgres@$MASTER_IP "repmgr -f /etc/repmgr/16/repmgr.conf cluster show" > /dev/null 2>&1; then
    echo "✅ Cluster repmgr fonctionnel"
    PGPASSWORD=$REPMR_PASSWORD ssh -o StrictHostKeyChecking=no postgres@$MASTER_IP "repmgr -f /etc/repmgr/16/repmgr.conf cluster show"
else
    echo "❌ Cluster repmgr non fonctionnel"
    exit 1
fi

# Test de réplication
echo "🔍 Test de réplication..."
MASTER_DATA=$(PGPASSWORD=$POSTGRES_PASSWORD psql -h $MASTER_IP -U postgres -d postgres -tAc "SELECT COUNT(*) FROM pg_stat_replication;")
if [ "$MASTER_DATA" -gt 0 ]; then
    echo "✅ Réplication active"
else
    echo "⚠️  Réplication inactive ou non détectée"
fi

echo ""
echo "🎉 Tests terminés avec succès !"
echo "=============================="
