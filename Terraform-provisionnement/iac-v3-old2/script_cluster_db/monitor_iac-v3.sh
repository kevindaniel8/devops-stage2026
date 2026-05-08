#!/bin/bash

# Script de monitoring - iac-v3
# ==============================

set -e

MASTER_IP="192.168.20.20"
REPLICA_IP="192.168.20.21"
SSH_KEY="${SSH_KEY:-~/.ssh/id_ed25519_terraform-proxmox}"

echo "🔍 Monitoring cluster PostgreSQL repmgr - iac-v3"
echo "================================================="
echo ""

# Fonction test état nœud
test_node() {
    local ip=$1
    local name=$2
    
    echo "📊 Test $name ($ip)..."
    
    # Test SSH
    if ! ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=3 ubuntu@$ip "echo OK" >/dev/null 2>&1; then
        echo "  ❌ SSH indisponible"
        return 1
    fi
    
    # Test repmgr
    local role=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$ip "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show 2>/dev/null | grep -E '^\s*[0-9]+' | grep '$ip' | awk '{print \$3}'" 2>/dev/null || echo "unknown")
    
    if [ "$role" = "primary" ]; then
        echo "  ✅ $name: MASTER (primary running)"
        return 0
    elif [ "$role" = "standby" ]; then
        echo "  ✅ $name: REPLICA (standby running)"
        return 0
    else
        echo "  ❌ $name: Rôle inconnu ou erreur"
        return 1
    fi
}

# Test réplication
test_replication() {
    echo ""
    echo "📊 Test réplication..."
    
    local repl_status=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo -u postgres psql -c 'SELECT state FROM pg_stat_replication;' 2>/dev/null | grep -E 'streaming|catchup' || echo 'none'" 2>/dev/null)
    
    if [ "$repl_status" = "none" ]; then
        echo "  ⚠️ Pas de connexion de réplication détectée"
    else
        echo "  ✅ Réplication active: $repl_status"
        
        # Détails réplication
        ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo -u postgres psql -c 'SELECT client_addr, state, sent_lsn, replay_lsn FROM pg_stat_replication;'" 2>/dev/null || true
    fi
}

# Monitoring principal
echo "🔍 Début du monitoring..."
echo ""

MASTER_OK=false
REPLICA_OK=false

if test_node "$MASTER_IP" "Master"; then
    MASTER_OK=true
fi

if test_node "$REPLICA_IP" "Replica"; then
    REPLICA_OK=true
fi

# Test réplication si master OK
if [ "$MASTER_OK" = true ]; then
    test_replication
fi

echo ""
echo "📋 Résumé du cluster :"
echo "======================="

if [ "$MASTER_OK" = true ] && [ "$REPLICA_OK" = true ]; then
    echo "✅ Cluster sain - les deux nœuds sont UP"
elif [ "$MASTER_OK" = true ]; then
    echo "⚠️  Master UP, Replica DOWN"
elif [ "$REPLICA_OK" = true ]; then
    echo "⚠️  Replica UP (peut-être promu), Master DOWN"
else
    echo "💥 CRITIQUE : Les deux nœuds sont DOWN !"
fi

echo ""
echo "🔧 Commandes utiles :"
echo "  Bascule manuelle: ./failover_iac-v3.sh"
echo "  Test complet: ./test_iac-v3.sh"
