#!/bin/bash

# Script de déploiement iac-v3 - Cluster PostgreSQL sur VMs Terraform/Proxmox
# ==================================================

set -e

echo "🚀 Déploiement Cluster PostgreSQL - iac-v3"
echo "============================================"

# Variables
MASTER_IP="192.168.20.20"
REPLICA_IP="192.168.20.21"
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"postgres_secure_password"}
REPMGR_PASSWORD=${REPMGR_PASSWORD:-"repmgr_secure_password"}

# Chemins
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IAC_V3_DIR="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$IAC_V3_DIR/ansible"

echo "📊 Configuration :"
echo "   Master: $MASTER_IP"
echo "   Replica: $REPLICA_IP"
echo "   Ansible: $ANSIBLE_DIR"
echo ""

# Étape 1: Vérification des VMs
echo "🔍 Étape 1: Vérification des VMs..."
echo "==================================="

# Test de connectivité SSH
if ! ssh -i ~/.ssh/id_ed25519_terraform-proxmox -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$MASTER_IP "echo 'OK'" 2>/dev/null; then
    echo "❌ Master ($MASTER_IP) inaccessible"
    echo "   Vérifiez que la VM est démarrée avec Terraform :"
    echo "   cd $IAC_V3_DIR && terraform apply"
    exit 1
fi

echo "✅ Master accessible"

if ! ssh -i ~/.ssh/id_ed25519_terraform-proxmox -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$REPLICA_IP "echo 'OK'" 2>/dev/null; then
    echo "❌ Replica ($REPLICA_IP) inaccessible"
    echo "   Vérifiez que la VM est démarrée avec Terraform :"
    echo "   cd $IAC_V3_DIR && terraform apply"
    exit 1
fi

echo "✅ Replica accessible"
echo ""

# Étape 2: Déploiement PostgreSQL avec Ansible
echo "🏗️  Étape 2: Déploiement PostgreSQL + repmgr"
echo "=============================================="

cd "$ANSIBLE_DIR"

# Déploiement du cluster
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy-cluster-db.yml \
  --extra-vars "postgres_password=$POSTGRES_PASSWORD repmgr_password=$REPMGR_PASSWORD"

echo ""
echo "🎉 Déploiement terminé !"
echo "========================="
echo ""
echo "📱 Connexions :"
echo "   Master : $MASTER_IP:5432 (postgres/$POSTGRES_PASSWORD)"
echo "   Replica : $REPLICA_IP:5432 (postgres/$POSTGRES_PASSWORD)"
echo ""
echo "🔧 Commandes de vérification :"
echo "   # Statut du cluster"
echo "   ansible -i inventories/dev/hosts.yml database -m shell -a \"repmgr -f /etc/repmgr/16/repmgr.conf cluster show\" -b"
echo ""
echo "   # Connexion directe master"
echo "   psql -h $MASTER_IP -U postgres -d postgres"
echo ""
echo "   # Connexion directe replica"
echo "   psql -h $REPLICA_IP -U postgres -d postgres"
echo ""
echo "🔄 Bascule manuelle (si nécessaire) :"
echo "   ansible-playbook -i inventories/dev/hosts.yml roles/cluster-db/failover.yml"
echo ""
