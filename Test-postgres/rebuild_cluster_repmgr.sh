#!/bin/bash

echo "🔄 Recréation complète du cluster PostgreSQL avec repmgr"
echo "=================================================="

# Variables avec mots de passe par défaut
export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
export REPMGR_PASSWORD=${REPMGR_PASSWORD:-repmgr_password}

echo ""
echo "🔑 Configuration des mots de passe :"
echo "   - PostgreSQL: $POSTGRES_PASSWORD"
echo "   - Repmgr: $REPMGR_PASSWORD"
echo ""
echo "💡 Vous pouvez personnaliser avec :"
echo "   export POSTGRES_PASSWORD=votre_mot_de_passe"
echo "   export REPMGR_PASSWORD=votre_mot_de_passe_repmgr"
echo ""

echo "🗑️  Étape 1: Nettoyage complet"
echo "================================="

# Arrêter et détruire les VMs existantes
echo "🔄 Arrêt des VMs..."
cd postgres1
vagrant halt --force 2>/dev/null || true
cd ../postgres2
vagrant halt --force 2>/dev/null || true
cd ..

echo "🗑️  Destruction des VMs..."
cd postgres1
vagrant destroy --force 2>/dev/null || true
cd ../postgres2
vagrant destroy --force 2>/dev/null || true
cd ..

echo ""
echo "🏗️  Étape 2: Création des VMs"
echo "============================="

# Créer et démarrer les VMs
echo "🚀 Création du master..."
cd postgres1
vagrant up
cd ..

echo "🚀 Création du slave..."
cd postgres2
vagrant up
cd ..

echo ""
echo "⚙️  Étape 3: Provisionnement"
echo "=========================="

# Provisionner le master
echo "🔧 Provisionnement du master..."
cd postgres1
vagrant ssh -c "sudo POSTGRES_PASSWORD=$POSTGRES_PASSWORD REPMGR_PASSWORD=$REPMGR_PASSWORD bash /vagrant/provision_master_repmgr.sh"
cd ..

# Attendre que le master soit prêt
echo "⏳ Attente du master..."
sleep 10

# Provisionner le slave
echo "🔧 Provisionnement du slave..."
cd postgres2
vagrant ssh -c "sudo POSTGRES_PASSWORD=$POSTGRES_PASSWORD REPMGR_PASSWORD=$REPMGR_PASSWORD bash /vagrant/provision_slave_repmgr.sh"
cd ..

echo ""
echo "🔍 Étape 4: Vérification"
echo "======================="

# Vérifier le cluster
echo "📊 Vérification du cluster..."
./monitor_cluster_repmgr.sh

echo ""
echo "🎉 Cluster PostgreSQL repmgr créé avec succès !"
echo "=============================================="
echo ""
echo "📱 Connexions DBeaver :"
echo "   Master: 192.168.56.21:5432 (postgres/$POSTGRES_PASSWORD)"
echo "   Slave:  192.168.56.22:5432 (postgres/$POSTGRES_PASSWORD)"
echo ""
echo " Scripts disponibles :"
echo "   ./monitor_cluster_repmgr.sh    - Monitoring du cluster"
echo "   ./failover_repmgr.sh           - Bascule manuelle"
echo ""
