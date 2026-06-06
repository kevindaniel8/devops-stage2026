#!/bin/bash

# Script de gestion cluster - Menu interactif iac-v3
# ===================================================

set -e

MASTER_IP="192.168.20.20"
REPLICA_IP="192.168.20.21"
SSH_KEY="${SSH_KEY:-~/.ssh/id_ed25519_terraform-proxmox}"

# Fonctions
test_master() {
    echo "📊 Test master ($MASTER_IP)..."
    if ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=3 ubuntu@$MASTER_IP "echo OK" >/dev/null 2>&1; then
        local role=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show 2>/dev/null | grep 'primary.*running' || echo ''" 2>/dev/null)
        if [ -n "$role" ]; then
            echo "✅ Master OK (primary running)"
            return 0
        else
            echo "❌ Master n'est pas primary"
            return 1
        fi
    else
        echo "❌ Master SSH indisponible"
        return 1
    fi
}

test_replica() {
    echo "📊 Test replica ($REPLICA_IP)..."
    if ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=3 ubuntu@$REPLICA_IP "echo OK" >/dev/null 2>&1; then
        local role=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$REPLICA_IP "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show 2>/dev/null | grep -E 'standby.*running|primary.*running' || echo ''" 2>/dev/null)
        if [ -n "$role" ]; then
            echo "✅ Replica OK"
            return 0
        else
            echo "❌ Replica DOWN"
            return 1
        fi
    else
        echo "❌ Replica SSH indisponible"
        return 1
    fi
}

show_cluster() {
    echo "🔍 Statut du cluster:"
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show" 2>/dev/null || \
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$REPLICA_IP "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show"
}

promote_replica() {
    echo "🚀 Promotion replica -> master..."
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$REPLICA_IP "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf standby promote"
    echo "✅ Replica promu master"
}

# Menu principal
show_menu() {
    echo ""
    echo "🎯 Gestion Cluster PostgreSQL - iac-v3"
    echo "====================================="
    echo "1) Statut du cluster"
    echo "2) Test master"
    echo "3) Test replica"
    echo "4) Bascule manuelle (failover)"
    echo "5) Monitoring complet"
    echo "6) Test réplication"
    echo "7) Quitter"
    echo ""
}

# Gestion des paramètres
case "$1" in
    "status")
        show_cluster
        ;;
    "test-master")
        test_master
        ;;
    "test-replica")
        test_replica
        ;;
    "promote")
        promote_replica
        ;;
    "monitor")
        ./monitor_iac-v3.sh
        ;;
    "test")
        ./test_iac-v3.sh
        ;;
    *)
        # Menu interactif
        while true; do
            show_menu
            read -p "Choisissez une option (1-7): " choice
            case $choice in
                1)
                    show_cluster
                    ;;
                2)
                    test_master
                    ;;
                3)
                    test_replica
                    ;;
                4)
                    ./failover_iac-v3.sh
                    ;;
                5)
                    ./monitor_iac-v3.sh
                    ;;
                6)
                    ./test_iac-v3.sh
                    ;;
                7)
                    echo "👋 Au revoir !"
                    exit 0
                    ;;
                *)
                    echo "❌ Option invalide"
                    ;;
            esac
        done
        ;;
esac
