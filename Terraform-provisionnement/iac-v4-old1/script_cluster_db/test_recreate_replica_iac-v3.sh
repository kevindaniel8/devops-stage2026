#!/bin/bash

# Script de test recréation replica - iac-v3
# ===========================================

set -e

echo "🔄 Test recréation de la replica - iac-v3"
echo "=========================================="

MASTER_IP="192.168.20.20"
REPLICA_IP="192.168.20.21"
REPMGR_PASSWORD=${REPMGR_PASSWORD:-"repmgr_secure_password"}
SSH_KEY="${SSH_KEY:-~/.ssh/id_ed25519_terraform-proxmox}"

echo "📊 Configuration :"
echo "   Master: $MASTER_IP"
echo "   Replica: $REPLICA_IP"
echo ""

# Étape 1: Arrêt PostgreSQL sur replica
echo "🛑 Étape 1: Arrêt PostgreSQL sur replica..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$REPLICA_IP "sudo systemctl stop postgresql@16-main" || true
sleep 2

# Étape 2: Nettoyage des données
echo "🗑️ Étape 2: Nettoyage des données..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$REPLICA_IP "sudo rm -rf /var/lib/postgresql/16/main/*"

# Étape 3: Clonage depuis master
echo "📥 Étape 3: Clonage depuis master..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$REPLICA_IP "sudo -u postgres bash -c 'export PGPASSWORD=$REPMGR_PASSWORD && repmgr -f /etc/repmgr/16/repmgr.conf standby clone -h $MASTER_IP -U repmgr -d repmgr --force'"

# Étape 4: Démarrage PostgreSQL
echo "🚀 Étape 4: Démarrage PostgreSQL..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$REPLICA_IP "sudo systemctl start postgresql@16-main"
sleep 5

# Étape 5: Enregistrement comme standby
echo "📝 Étape 5: Enregistrement comme standby..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$REPLICA_IP "sudo -u postgres bash -c 'export PGPASSWORD=$REPMGR_PASSWORD && repmgr -f /etc/repmgr/16/repmgr.conf standby register --force'" || true

# Étape 6: Vérification
echo ""
echo "🔍 Étape 6: Vérification..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show"

echo ""
echo "🎉 Recréation terminée !"
