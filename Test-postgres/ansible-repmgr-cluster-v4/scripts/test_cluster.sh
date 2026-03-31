#!/bin/bash

# Script de test V4 - Validation du cluster
# ======================================

set -e

echo "🧪 Tests du cluster PostgreSQL repmgr V4"
echo "======================================="

# Test 1: Vérification statut master
echo "📊 Test 1: Statut master"
vagrant ssh master -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show" || echo "❌ Master inaccessible"

# Test 2: Vérification statut replica
echo ""
echo "📊 Test 2: Statut replica"
vagrant ssh replica -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show" || echo "❌ Replica inaccessible"

# Test 3: Vérification réplication
echo ""
echo "📊 Test 3: Statut réplication"
vagrant ssh master -c "sudo -u postgres psql -c 'SELECT * FROM pg_stat_replication;'" || echo "❌ Réplication inaccessible"

# Test 4: Test de connexion PostgreSQL
echo ""
echo "� Test 4: Connexion PostgreSQL"
vagrant ssh master -c "sudo -u postgres psql -c 'SELECT version();'" || echo "❌ Connexion master impossible"
vagrant ssh replica -c "sudo -u postgres psql -c 'SELECT version();'" || echo "❌ Connexion replica impossible"

echo ""
echo "🎉 Tests terminés !"
