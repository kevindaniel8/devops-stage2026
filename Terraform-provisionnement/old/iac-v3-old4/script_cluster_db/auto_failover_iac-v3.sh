#!/bin/bash

# Script de bascule automatique - iac-v3
# =====================================

set -e

echo "🔄 Système de bascule automatique"
echo "================================"

MASTER_IP="192.168.20.20"
REPLICA_IP="192.168.20.21"
SSH_KEY="${SSH_KEY:-~/.ssh/id_ed25519_terraform-proxmox}"
REPMGR_PASSWORD=${REPMGR_PASSWORD:-"repmgr_secure_password"}

# Fonction de vérification de santé
check_health() {
    local ip=$1
    local name=$2
    
    if ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=3 ubuntu@$ip "sudo -u postgres pg_isready -h /var/run/postgresql -p 5432" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Vérification initiale
echo "🔍 Vérification initiale du cluster..."
MASTER_HEALTH=0
REPLICA_HEALTH=0

if check_health "$MASTER_IP" "Master"; then
    echo "🟢 Master: OK"
    MASTER_HEALTH=1
else
    echo "❌ Master: DOWN"
fi

if check_health "$REPLICA_IP" "Replica"; then
    echo "🟢 Replica: OK"
    REPLICA_HEALTH=1
else
    echo "❌ Replica: DOWN"
fi

echo ""

# Décision de bascule
if [ $MASTER_HEALTH -eq 1 ] && [ $REPLICA_HEALTH -eq 1 ]; then
    echo "✅ Cluster sain - aucune action nécessaire"
    exit 0
fi

if [ $MASTER_HEALTH -eq 0 ] && [ $REPLICA_HEALTH -eq 0 ]; then
    echo "🚨 CRITIQUE : Master ET Replica sont down !"
    echo "🔧 Action manuelle requise"
    exit 1
fi

if [ $MASTER_HEALTH -eq 0 ]; then
    echo "🔥 Master down - Promotion de la replica..."
    
    # Promouvoir la replica
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$REPLICA_IP "sudo -u postgres bash -c 'export PGPASSWORD=$REPMGR_PASSWORD && repmgr -f /etc/repmgr/16/repmgr.conf standby promote'"
    
    echo "✅ Replica promue en master"
    echo ""
    echo "📍 Nouveau master: $REPLICA_IP"
    echo "⚠️  L'ancien master ($MASTER_IP) doit être reconfiguré manuellement comme replica"
    exit 0
fi

if [ $REPLICA_HEALTH -eq 0 ]; then
    echo "🔥 Replica down - Recréation nécessaire..."
    echo "🔄 Utilisez: ./test_recreate_replica_iac-v3.sh"
    exit 1
fi

echo "🤔 État inconnu - aucune action"
exit 1
