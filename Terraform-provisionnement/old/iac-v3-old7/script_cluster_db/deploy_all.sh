#!/bin/bash

# Script de déploiement complet du cluster PostgreSQL repmgr
# =====================================================

set -e

echo "🚀 Déploiement complet du cluster PostgreSQL repmgr"
echo "=============================================="

# Variables
MASTER_IP="192.168.56.21"
REPLICA_IP="192.168.56.22"
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"postgres"}
REPMR_PASSWORD=${REPMR_PASSWORD:-"repmgr_password"}

echo "📊 Configuration :"
echo "   Master: $MASTER_IP"
echo "   Replica: $REPLICA_IP"
echo ""

# Étape 1: Création du master
echo "🏗️  Étape 1: Création du master..."
vagrant up master

echo ""
echo "✅ Master créé"
echo ""

# Étape 2: Création du replica
echo "🏗️  Étape 2: Création du replica..."
vagrant up replica

echo ""
echo "✅ Replica créé"
echo ""

# Étape 3: Configuration repmgr du cluster
echo "🔧 Étape 3: Configuration repmgr du cluster..."
vagrant up cluster_setup

echo ""
echo "🎉 Déploiement terminé !"
echo "======================"
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
