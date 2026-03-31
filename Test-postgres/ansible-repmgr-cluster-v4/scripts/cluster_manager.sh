#!/bin/bash

# Script de gestion cluster V4 - Menu interactif
# ==========================================

set -e

# Variables
MASTER_IP="192.168.56.21"
REPLICA_IP="192.168.56.22"
NEW_SERVER_IP="192.168.56.23"
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"postgres"}
REPMGR_PASSWORD=${REPMGR_PASSWORD:-"repmgr_password"}

# Fonctions
check_vm_status() {
    local vm_name=$1
    if vagrant status $vm_name | grep -q "running"; then
        return 0
    elif vagrant status $vm_name | grep -q "poweroff"; then
        return 1
    elif vagrant status $vm_name | grep -q "not created"; then
        return 2
    else
        return 3
    fi
}

create_replica() {
    echo "🏗️  Création nouvelle replica..."
    vagrant destroy newserver --force 2>/dev/null || true
    vagrant up newserver --no-provision
    ansible-playbook -i inventory/production.ini playbooks/deploy_cluster_robuste.yml \
        --extra-vars "postgres_password=$POSTGRES_PASSWORD repmgr_password=$REPMGR_PASSWORD" \
        --limit "newserver"
    echo "✅ Nouvelle replica créée"
}

promote_replica() {
    echo "🚀 Promotion replica -> master..."
    vagrant ssh replica -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf standby promote"
    echo "✅ Replica promu master"
}

test_master() {
    echo "📊 Test master..."
    if check_vm_status "master"; then
        if vagrant ssh master -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show" 2>/dev/null | grep -q "primary.*running"; then
            echo "✅ Master OK"
            return 0
        else
            echo "❌ Master DOWN"
            return 1
        fi
    else
        echo "❌ Master VM non running"
        return 1
    fi
}

test_replica() {
    echo "📊 Test replica..."
    if check_vm_status "replica"; then
        if vagrant ssh replica -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show" 2>/dev/null | grep -q "standby.*running"; then
            echo "✅ Replica OK"
            return 0
        else
            echo "❌ Replica DOWN"
            return 1
        fi
    else
        echo "❌ Replica VM non running"
        return 1
    fi
}

monitor_cluster() {
    echo "🔍 Monitoring complet du cluster..."
    vagrant status
    echo ""
    
    if ! test_master; then
        if test_replica; then
            promote_replica
        else
            echo "💥 Les deux nœuds sont DOWN !"
        fi
    fi
    
    if ! test_replica; then
        create_replica
    fi
    
    echo ""
    vagrant status
}

# Menu principal
show_menu() {
    echo ""
    echo "🎯 Gestion Cluster PostgreSQL V4"
    echo "==============================="
    echo "1) Monitoring complet"
    echo "2) Test master"
    echo "3) Test replica"
    echo "4) Créer replica"
    echo "5) Promouvoir replica"
    echo "6) Status VMs"
    echo "7) Quitter"
    echo ""
}

# Gestion des paramètres
case "$1" in
    "monitor")
        monitor_cluster
        ;;
    "test-master")
        test_master
        ;;
    "test-replica")
        test_replica
        ;;
    "create-replica")
        create_replica
        ;;
    "promote")
        promote_replica
        ;;
    "status")
        vagrant status
        ;;
    *)
        # Menu interactif
        while true; do
            show_menu
            read -p "Choisissez une option (1-7): " choice
            case $choice in
                1)
                    monitor_cluster
                    ;;
                2)
                    test_master
                    ;;
                3)
                    test_replica
                    ;;
                4)
                    create_replica
                    ;;
                5)
                    promote_replica
                    ;;
                6)
                    vagrant status
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
