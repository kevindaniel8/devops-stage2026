#!/bin/bash

# Script de test - Recréation replica seulement
# =========================================

set -e

echo "🧪 Test recréation replica V4"
echo "=============================="

# Variables
NEW_SERVER_IP="192.168.56.23"
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"postgres"}
REPMGR_PASSWORD=${REPMGR_PASSWORD:-"repmgr_password"}

echo "📊 Configuration :"
echo "   NewServer: $NEW_SERVER_IP"
echo ""

# Étape 1: Nettoyage VM newserver
echo "🗑️  Étape 1: Nettoyage VM newserver..."
vagrant destroy newserver --force 2>/dev/null || true
echo "✅ Nettoyage terminé"

# Étape 2: Création nouvelle VM replica
echo ""
echo "🏗️  Étape 2: Création nouvelle VM replica..."
cd /home/kevin/Test-postgres/ansible-repmgr-cluster-v4

# Créer nouvelle VM replica
vagrant up newserver --no-provision

echo "✅ VM créée"

# Étape 3: Configuration avec Ansible
echo ""
echo "⚙️  Étape 3: Configuration Ansible..."
ansible-playbook -i inventory/production.ini playbooks/deploy_cluster_robuste.yml \
    --extra-vars "postgres_password=$POSTGRES_PASSWORD repmgr_password=$REPMGR_PASSWORD" \
    --limit "newserver"

echo ""
echo "🎉 Test recréation replica terminé !"
echo "=================================="

# Vérification
echo "📊 Vérification de la nouvelle replica :"
vagrant ssh newserver -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show" || echo "❌ NewServer inaccessible"
