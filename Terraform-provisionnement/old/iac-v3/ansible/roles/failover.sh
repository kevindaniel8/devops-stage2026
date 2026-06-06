#!/bin/bash

# Script de bascule manuelle du cluster PostgreSQL repmgr
# ==================================================

set -e

echo "🔄 Bascule manuelle du cluster PostgreSQL repmgr"
echo "=========================================="

# Variables
MASTER_IP="192.168.56.21"
REPLICA_IP="192.168.56.22"
REPMR_PASSWORD=${REPMR_PASSWORD:-"repmgr_password"}

echo "📊 Configuration :"
echo "   Master: $MASTER_IP"
echo "   Replica: $REPLICA_IP"
echo ""

# Vérification de l'état actuel
echo "🔍 État actuel du cluster:"
PGPASSWORD=$REPMR_PASSWORD ssh -o StrictHostKeyChecking=no postgres@$MASTER_IP "repmgr -f /etc/repmgr/16/repmgr.conf cluster show"
echo ""

# Promotion du replica
echo "🚀 Promotion du replica en master..."
if PGPASSWORD=$REPMR_PASSWORD ssh -o StrictHostKeyChecking=no postgres@$REPLICA_IP "repmgr -f /etc/repmgr/16/repmgr.conf standby promote"; then
    echo "✅ Promotion réussie"
else
    echo "❌ Échec de la promotion"
    exit 1
fi

echo ""
echo "📊 Nouveau statut du cluster:"
PGPASSWORD=$REPMR_PASSWORD ssh -o StrictHostKeyChecking=no postgres@$REPLICA_IP "repmgr -f /etc/repmgr/16/repmgr.conf cluster show"

echo ""
echo "🎉 Bascule terminée avec succès !"
echo "================================"
echo ""
echo "📍 Nouveau master: $REPLICA_IP"
echo "🔧 Ancien master: $MASTER_IP (arrêté)"
