#!/bin/bash

# Script de monitoring V4 - Auto-récupération
# =========================================

set -e

MASTER_IP="192.168.56.21"
REPLICA_IP="192.168.56.22"
NEW_SERVER_IP="192.168.56.23"
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"postgres"}
REPMGR_PASSWORD=${REPMGR_PASSWORD:-"repmgr_password"}

echo "🔍 Monitoring cluster PostgreSQL repmgr"
echo "=================================="

# Fonction test état VM
check_vm_status() {
    local vm_name=$1
    echo "🔍 État VM $vm_name..."
    if vagrant status $vm_name | grep -q "running"; then
        echo "✅ VM $vm_name est running"
        return 0
    elif vagrant status $vm_name | grep -q "poweroff"; then
        echo "⚠️  VM $vm_name est poweroff"
        return 1
    elif vagrant status $vm_name | grep -q "not created"; then
        echo "❌ VM $vm_name n'existe pas"
        return 2
    else
        echo "❓ VM $vm_name état inconnu"
        return 3
    fi
}

# Fonction test master
test_master() {
    echo "📊 Test master ($MASTER_IP)..."
    
    # Vérifier état VM
    if ! check_vm_status "master"; then
        echo "❌ Master VM non running"
        return 1
    fi
    
    # Vérifier service repmgr
    if vagrant ssh master -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show" 2>/dev/null | grep -q "primary.*running"; then
        echo "✅ Master OK"
        return 0
    else
        echo "❌ Master DOWN"
        return 1
    fi
}

# Fonction test replica
test_replica() {
    echo "📊 Test replica ($REPLICA_IP)..."
    
    # Vérifier état VM
    if ! check_vm_status "replica"; then
        echo "❌ Replica VM non running"
        return 1
    fi
    
    # Vérifier si c'est maintenant un master (promu)
    if vagrant ssh replica -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show" 2>/dev/null | grep -q "primary.*running"; then
        echo "✅ Replica promu en master (primary running)"
        return 0
    # Vérifier si c'est encore une replica
    elif vagrant ssh replica -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show" 2>/dev/null | grep -q "standby.*running"; then
        echo "✅ Replica OK (standby running)"
        return 0
    else
        echo "❌ Replica DOWN (ni primary ni standby)"
        return 1
    fi
}

# Fonction promotion replica -> master
promote_replica() {
    echo "🚀 Promotion replica -> master..."
    vagrant ssh replica -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf standby promote"
    echo "✅ Replica promu master"
}

# Fonction création nouvelle replica
create_replica() {
    echo "🏗️  Création nouvelle replica..."
    cd /home/kevin/Test-postgres/ansible-repmgr-cluster-v4
    
    # Déterminer l'IP du master actuel
    local current_master_ip
    if vagrant ssh master -c "echo 'master_up'" >/dev/null 2>&1; then
        current_master_ip=$MASTER_IP
    elif vagrant ssh replica -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show" 2>/dev/null | grep -q "primary.*running"; then
        current_master_ip=$REPLICA_IP
    else
        echo "❌ Impossible de déterminer le master actuel"
        return 1
    fi
    
    echo "📍 Master actuel détecté : $current_master_ip"
    
    # Créer nouvelle VM replica
    vagrant destroy newserver --force 2>/dev/null || true
    vagrant up newserver --no-provision
    
    # Configurer avec Ansible en utilisant le master actuel
    ansible-playbook -i inventory/production.ini playbooks/deploy_cluster_robuste.yml \
        --extra-vars "postgres_password=$POSTGRES_PASSWORD repmgr_password=$REPMGR_PASSWORD master_ip=$current_master_ip" \
        --limit "newserver"
    
    echo "✅ Nouvelle replica créée et connectée à $current_master_ip"
}

# Monitoring principal
echo "📋 État des VMs avant monitoring :"
vagrant status

echo ""
echo "🔍 Début du monitoring..."

# Vérifier si master est down
if ! test_master; then
    echo "🔥 Master détecté DOWN"
    
    # Vérifier si replica est OK
    if test_replica; then
        echo "✅ Replica disponible et fonctionnel"
        # Vérifier si c'est déjà promu
        if vagrant ssh replica -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show" 2>/dev/null | grep -q "primary.*running"; then
            echo "✅ Replica déjà promu en master"
        else
            echo "🔄 Promotion replica en master..."
            promote_replica
            echo "✅ Replica promu master avec succès"
        fi
    else
        echo "💥 Les deux nœuds sont DOWN !"
        echo "🔧 Action manuelle requise : vagrant up master replica"
        exit 1
    fi
    
    # Après promotion, vérifier si on doit créer une nouvelle replica
    echo ""
    echo "🔍 Vérification après promotion..."
    
    # Vérifier si on a une replica disponible (si l'ancienne replica est devenue master, il faut en créer une nouvelle)
    if ! vagrant ssh replica -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show" 2>/dev/null | grep -q "primary.*running"; then
        echo "✅ Replica toujours disponible (standby)"
    else
        echo "🔥 Pas de replica disponible (l'ancienne est devenue master)"
        echo "🔄 Création nouvelle replica..."
        create_replica
    fi
else
    # Master OK, vérifier replica
    if ! test_replica; then
        echo "🔥 Replica détecté DOWN"
        echo "🔄 Création nouvelle replica..."
        create_replica
    fi
fi

echo ""
echo "📋 État final des VMs :"
vagrant status

echo ""
echo "🎉 Cluster monitoring terminé"
