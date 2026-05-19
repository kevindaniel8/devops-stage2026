#!/bin/bash

# Script de déploiement V4 - Monitoring et auto-récupération
# =======================================================

set -e

echo "🚀 Déploiement V4 - Monitoring et auto-récupération"
echo "================================================="

# Variables
MASTER_IP="192.168.56.21"
REPLICA_IP="192.168.56.22"
NEW_SERVER_IP="192.168.56.23"
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"postgres"}
REPMGR_PASSWORD=${REPMGR_PASSWORD:-"repmgr_password"}

echo "📊 Configuration :"
echo "   Master: $MASTER_IP"
echo "   Replica: $REPLICA_IP"
echo "   NewServer: $NEW_SERVER_IP"
echo ""

# Étape 1: Nettoyage complet
echo "🗑️  Étape 1: Nettoyage complet..."
echo "================================="

# Forcer arrêt des VMs
VBoxManage list runningvms | grep -o '"[^"]*"' | xargs -I {} VBoxManage controlvm {} poweroff 2>/dev/null || true

# Détruire les VMs
vagrant halt --force 2>/dev/null || true
vagrant destroy --force 2>/dev/null || true

# Nettoyer .vagrant
rm -rf .vagrant 2>/dev/null || true

echo ""
echo "🏗️  Étape 2: Création des VMs master et replica"
echo "=============================================="

# Créer les VMs master et replica
vagrant up master replica --provision

echo ""
echo "🎉 Déploiement V4 terminé !"
echo "============================="
echo ""
echo "📱 Connexions :"
echo "   Master : $MASTER_IP:5432 (postgres/$POSTGRES_PASSWORD)"
echo "   Replica : $REPLICA_IP:5432 (postgres/$POSTGRES_PASSWORD)"
echo ""
echo "🔧 Monitoring :"
echo "   ./scripts/monitor_cluster.sh"
echo ""
echo "🔄 Tests manuels :"
echo "   vagrant ssh master -c 'sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show'"
echo "   vagrant ssh replica -c 'sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show'"
