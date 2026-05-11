#!/bin/bash

# Script de déploiement robuste du cluster PostgreSQL repmgr V2
# =============================================================

set -e

echo "🚀 Déploiement ROBUSTE du cluster PostgreSQL repmgr V2"
echo "=================================================="

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

# Arrêter et détruire les VMs existantes
echo "🔄 Arrêt des VMs..."
vagrant halt --force 2>/dev/null || true

echo "🗑️  Destruction des VMs..."
vagrant destroy --force 2>/dev/null || true

echo ""
echo "🏗️  Étape 2: Création des VMs"
echo "============================="

# Créer et démarrer les VMs avec retry
echo "🚀 Création du master..."
for i in {1..3}; do
    if vagrant up master --no-provision; then
        echo "✅ Master créé avec succès"
        break
    else
        echo "⚠️  Tentative $i/3 pour le master..."
        sleep 10
    fi
done

echo "🚀 Création du replica..."
for i in {1..3}; do
    if vagrant up replica --no-provision; then
        echo "✅ Replica créé avec succès"
        break
    else
        echo "⚠️  Tentative $i/3 pour le replica..."
        sleep 10
    fi
done

echo ""
echo "⚙️  Étape 3: Déploiement robuste"
echo "=================================="

# Déploiement avec retry
echo "🔧 Déploiement du cluster..."
for i in {1..3}; do
    if vagrant up cluster_setup; then
        echo "✅ Cluster configuré avec succès"
        break
    else
        echo "⚠️  Tentative $i/3 pour le configuration..."
        sleep 15
        vagrant halt cluster_setup --force || true
        vagrant destroy cluster_setup --force || true
    fi
done

echo ""
echo "🎉 Déploiement terminé !"
echo "====================="
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
