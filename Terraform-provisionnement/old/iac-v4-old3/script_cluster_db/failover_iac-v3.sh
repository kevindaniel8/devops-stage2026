#!/bin/bash

# Script de bascule manuelle - iac-v3
# ==================================

set -e

echo "🔄 Bascule manuelle du cluster PostgreSQL repmgr"
echo "================================================="

# Variables
MASTER_IP="192.168.20.20"
REPLICA_IP="192.168.20.21"
REPMGR_PASSWORD=${REPMGR_PASSWORD:-"repmgr_secure_password"}
SSH_KEY="${SSH_KEY:-~/.ssh/id_ed25519_terraform-proxmox}"

echo "📊 Configuration :"
echo "   Master: $MASTER_IP"
echo "   Replica: $REPLICA_IP"
echo ""

# Vérification de l'état actuel
echo "🔍 État actuel du cluster:"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show" 2>/dev/null || \
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$REPLICA_IP "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show"
echo ""

# Promotion du replica
echo "🚀 Promotion du replica en master..."
if ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$REPLICA_IP "sudo -u postgres bash -c 'export PGPASSWORD=$REPMGR_PASSWORD && repmgr -f /etc/repmgr/16/repmgr.conf standby promote'"; then
    echo "✅ Promotion réussie"
else
    echo "❌ Échec de la promotion"
    exit 1
fi

echo ""
echo "📊 Nouveau statut du cluster:"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$REPLICA_IP "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show"

echo ""
echo "🎉 Bascule terminée avec succès !"
echo "================================="
echo ""
echo "📍 Nouveau master: $REPLICA_IP"
echo "🔧 Ancien master: $MASTER_IP (doit être reconfiguré comme replica)"
echo ""
echo "💡 Pour reconfigurer l'ancien master comme replica:"
echo "   ssh -i $SSH_KEY ubuntu@$MASTER_IP \"sudo systemctl stop postgresql@16-main\""
echo "   ssh -i $SSH_KEY ubuntu@$MASTER_IP \"sudo -u postgres bash -c 'rm -rf /var/lib/postgresql/16/main/*'\""
echo "   ssh -i $SSH_KEY ubuntu@$MASTER_IP \"sudo -u postgres bash -c 'export PGPASSWORD=$REPMGR_PASSWORD && repmgr -f /etc/repmgr/16/repmgr.conf standby clone -h $REPLICA_IP -U repmgr -d repmgr'\""
