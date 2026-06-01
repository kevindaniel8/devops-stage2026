#!/bin/bash

# Script de test iac-v3 - Validation du cluster PostgreSQL
# ==================================================

set -e

echo "🧪 Tests du cluster PostgreSQL repmgr - iac-v3"
echo "==============================================="

# Variables
MASTER_IP="192.168.20.20"
REPLICA_IP="192.168.20.21"
SSH_KEY="~/.ssh/id_ed25519_terraform-proxmox"

echo ""
echo "📊 Test 1: Vérification connectivité SSH"
echo "========================================="

ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "echo '✅ Master accessible'" || echo "❌ Master inaccessible"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$REPLICA_IP "echo '✅ Replica accessible'" || echo "❌ Replica inaccessible"

echo ""
echo "📊 Test 2: Statut du cluster repmgr"
echo "===================================="

echo "--- Statut depuis Master ---"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show" || echo "❌ Commande échouée"

echo ""
echo "📊 Test 3: Vérification PostgreSQL"
echo "==================================="

echo "--- Version PostgreSQL Master ---"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo -u postgres psql -c 'SELECT version();'" || echo "❌ Connexion impossible"

echo ""
echo "--- Version PostgreSQL Replica ---"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$REPLICA_IP "sudo -u postgres psql -c 'SELECT version();'" || echo "❌ Connexion impossible"

echo ""
echo "📊 Test 4: Statut réplication"
echo "=============================="

echo "--- Réplication sur Master ---"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo -u postgres psql -c 'SELECT client_addr, state, sent_lsn, replay_lsn FROM pg_stat_replication;'" || echo "❌ Pas de réplication"

echo ""
echo "📊 Test 5: Test écriture/lecture"
echo "================================="

# Création d'une table test
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo -u postgres psql -c 'CREATE TABLE IF NOT EXISTS test_replication (id serial PRIMARY KEY, created_at timestamp DEFAULT NOW());'" 2>/dev/null || true

# Insertion
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo -u postgres psql -c 'INSERT INTO test_replication DEFAULT VALUES;'" 2>/dev/null || true

# Vérification réplication
sleep 1

echo "--- Données sur Master ---"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo -u postgres psql -c 'SELECT * FROM test_replication ORDER BY id DESC LIMIT 3;'" || echo "❌ Lecture impossible"

echo ""
echo "--- Données sur Replica (lecture seule) ---"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$REPLICA_IP "sudo -u postgres psql -c 'SELECT * FROM test_replication ORDER BY id DESC LIMIT 3;'" || echo "⚠️  Réplication en cours ou erreur"

echo ""
echo "🎉 Tests terminés !"
echo "===================="
echo ""
echo "Pour nettoyer la table test :"
echo "  ssh -i $SSH_KEY ubuntu@$MASTER_IP \"sudo -u postgres psql -c 'DROP TABLE test_replication;'\""
