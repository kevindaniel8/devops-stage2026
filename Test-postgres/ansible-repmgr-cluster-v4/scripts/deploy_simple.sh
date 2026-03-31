#!/bin/bash

# Script de déploiement V3 - Une seule commande vagrant up
# ==================================================

set -e

echo "🚀 Déploiement V3 - Une seule commande"
echo "====================================="

# Variables
MASTER_IP="192.168.56.21"
REPLICA_IP="192.168.56.22"
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"postgres"}
REPMGR_PASSWORD=${REPMGR_PASSWORD:-"repmgr_password"}

echo "📊 Configuration :"
echo "   Master: $MASTER_IP"
echo "   Replica: $REPLICA_IP"
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
echo "🏗️  Étape 2: Création des VMs et configuration PostgreSQL"
echo "=================================================="

# Créer les VMs et configurer PostgreSQL en une seule commande
vagrant up master replica --provision

echo ""
echo "🔧 Étape 3: Configuration repmgr depuis l'hôte"
echo "=============================================="

# Configuration repmgr depuis l'hôte (ansible_local)
ansible-playbook -i inventory/production.ini playbooks/deploy_cluster_robuste.yml \
  --extra-vars "postgres_password=$POSTGRES_PASSWORD repmgr_password=$REPMGR_PASSWORD" \
  --limit "master,replica"

echo ""
echo "🎉 Déploiement V3 terminé !"
echo "==========================="
echo ""
echo "📱 Connexions :"
echo "   Master : $MASTER_IP:5432 (postgres/$POSTGRES_PASSWORD)"
echo "   Replica : $REPLICA_IP:5432 (postgres/$POSTGRES_PASSWORD)"
echo ""
echo "🔧 Tests :"
echo "   ./scripts/test_cluster.sh"
echo ""
echo "🔄 Bascule :"
echo "   ./scripts/failover.sh"
echo ""
echo "📊 Monitoring :"
echo "   vagrant ssh master -c 'sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show'"
