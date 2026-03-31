#!/bin/bash

# Script de bascule automatique avec remplacement
# =============================================

set -e

echo "🔄 Système de bascule automatique avec remplacement"
echo "=============================================="

# Variables
MASTER_IP="192.168.56.21"
REPLICA_IP="192.168.56.22"
REPLACEMENT_IP="192.168.56.23"
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"postgres"}
REPMGR_PASSWORD=${REPMGR_PASSWORD:-"repmgr_password"}

echo "📊 Configuration :"
echo "   Master: $MASTER_IP"
echo "   Replica: $REPLICA_IP"
echo "   Remplacement: $REPLACEMENT_IP"
echo ""

# Fonction de vérification de santé
check_health() {
    local ip=$1
    local name=$2
    
    if curl -s --connect-timeout 5 "http://$ip:5432" > /dev/null 2>&1; then
        echo "🟢 $name: OK"
        return 0
    else
        echo "❌ $name: DOWN"
        return 1
    fi
}

# Vérification initiale
echo "🔍 Vérification initiale du cluster..."
MASTER_HEALTH=$(check_health "$MASTER_IP" "Master" || echo "DOWN")
REPLICA_HEALTH=$(check_health "$REPLICA_IP" "Replica" || echo "DOWN")

echo ""

# Décision de bascule
if [ "$MASTER_HEALTH" = "OK" ] && [ "$REPLICA_HEALTH" = "OK" ]; then
    echo "✅ Cluster sain - aucune action nécessaire"
    exit 0
fi

if [ "$MASTER_HEALTH" = "DOWN" ] && [ "$REPLICA_HEALTH" = "DOWN" ]; then
    echo "🚨 CRITIQUE : Master ET Replica sont down !"
    echo "🚀 Lancement du nœud de remplacement..."
    
    # Lancer le remplacement
    cd /home/kevin/Test-postgres/ansible-repmgr-cluster
    export POSTGRES_PASSWORD=$POSTGRES_PASSWORD
    export REPMGR_PASSWORD=$REPMGR_PASSWORD
    export FAILED_MASTER=true
    export FAILED_REPLICA=true
    
    ansible-playbook -i inventory/production.ini playbooks/deploy_replacement.yml
    
    echo "🎉 Remplacement déployé"
    exit 0
fi

if [ "$MASTER_HEALTH" = "DOWN" ]; then
    echo "🔄 Master down - Promotion de la replica..."
    
    # Promouvoir la replica
    ssh -o StrictHostKeyChecking=no postgres@$REPLICA_IP "export PGPASSWORD=$REPMGR_PASSWORD && repmgr -f /etc/repmgr/16/repmgr.conf standby promote"
    
    echo "✅ Replica promue en master"
    exit 0
fi

if [ "$REPLICA_HEALTH" = "DOWN" ]; then
    echo "🔄 Replica down - Lancement du remplacement..."
    
    # Lancer le remplacement
    cd /home/kevin/Test-postgres/ansible-repmgr-cluster
    export POSTGRES_PASSWORD=$POSTGRES_PASSWORD
    export REPMGR_PASSWORD=$REPMGR_PASSWORD
    export FAILED_MASTER=false
    export FAILED_REPLICA=true
    
    ansible-playbook -i inventory/production.ini playbooks/deploy_replacement.yml
    
    echo "🎉 Remplacement déployé"
    exit 0
fi

echo "🤔 État inconnu - aucune action"
exit 1
