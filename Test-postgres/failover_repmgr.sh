#!/bin/bash

echo "🔄 Bascule manuelle du cluster PostgreSQL avec repmgr"
echo "=============================================="

MASTER_IP="192.168.56.21"
SLAVE_IP="192.168.56.22"

echo ""
echo "🔍 État actuel du cluster:"
./monitor_cluster_repmgr.sh

echo ""
echo "⚠️  ATTENTION: Vous allez effectuer une bascule manuelle"
echo "   - Le slave va être promu master"
echo "   - L'ancien master sera configuré comme slave"
echo ""

read -p "Êtes-vous sûr de vouloir continuer ? (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo "❌ Bascule annulée"
    exit 1
fi

echo ""
echo "🔄 Étape 1: Promotion du slave en master"
echo "======================================"

cd postgres2
echo "📝 Promotion du slave..."
vagrant ssh -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf standby promote"

echo ""
echo "🔄 Étape 2: Reconfiguration de l'ancien master"
echo "=========================================="

cd ../postgres1
echo "📝 Arrêt de l'ancien master..."
vagrant ssh -c "sudo systemctl stop postgresql"

echo "📝 Configuration de l'ancien master comme slave..."
vagrant ssh -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.sh standby follow --upstream-node-id=2 --force-rewind"

echo ""
echo "🔄 Étape 3: Vérification du nouveau cluster"
echo "======================================"

cd ..
echo "🔍 Nouvel état du cluster:"
./monitor_cluster_repmgr.sh

echo ""
echo "🎉 Bascule terminée avec succès !"
echo "================================"
echo "Nouveau master: $SLAVE_IP"
echo "Nouveau slave: $MASTER_IP"
