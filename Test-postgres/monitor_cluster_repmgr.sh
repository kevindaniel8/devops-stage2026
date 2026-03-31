#!/bin/bash

echo "🔍 Monitoring du cluster PostgreSQL avec repmgr"
echo "============================================"

MASTER_IP="192.168.56.21"
SLAVE_IP="192.168.56.22"
REPMGR_PASSWORD=${REPMGR_PASSWORD:-repmgr_password}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}

echo "📊 Cluster repmgr PostgreSQL"
echo "=========================="

# Vérifier master
echo ""
echo "📊 Master ($MASTER_IP):"
if pg_isready -h $MASTER_IP -U postgres > /dev/null 2>&1; then
    echo "✅ Master en ligne"
    
    # Vérifier l'état repmgr avec mot de passe
    echo "🔍 État repmgr master:"
    cd postgres1
    vagrant ssh -c "export PGPASSWORD=$REPMGR_PASSWORD && sudo -u postgres PGPASSWORD=$REPMGR_PASSWORD repmgr -f /etc/repmgr/16/repmgr.conf cluster show" 2>/dev/null || echo "❌ Impossible d'obtenir l'état repmgr"
    cd ..
    
else
    echo "❌ Master hors ligne"
fi

# Vérifier slave
echo ""
echo "📊 Slave ($SLAVE_IP):"
if pg_isready -h $SLAVE_IP -U postgres > /dev/null 2>&1; then
    echo "✅ Slave en ligne"
    
    # Vérifier si slave est en mode recovery
    cd postgres2
    RECOVERY_MODE=$(vagrant ssh -c "sudo -u postgres psql -tAc 'SELECT pg_is_in_recovery();'" 2>/dev/null | tr -d ' ')
    if [ "$RECOVERY_MODE" = "t" ]; then
        echo "✅ Slave en mode recovery"
        
        # Vérifier l'état repmgr
        echo "🔍 État repmgr slave:"
        vagrant ssh -c "export PGPASSWORD=$REPMGR_PASSWORD && sudo -u postgres PGPASSWORD=$REPMGR_PASSWORD repmgr -f /etc/repmgr/16/repmgr.conf status" 2>/dev/null || echo "❌ Impossible d'obtenir l'état repmgr"
        
    else
        echo "⚠️  Slave n'est pas en mode recovery (peut-être promu master)"
    fi
    cd ..
    
else
    echo "❌ Slave hors ligne"
fi

# Test de réplication
echo ""
echo "🧪 Test de réplication:"
echo "Connexion master..."
if PGPASSWORD=$POSTGRES_PASSWORD psql -h $MASTER_IP -U postgres -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ Connexion master OK"
else
    echo "❌ Connexion master échouée"
fi

echo "Connexion slave..."
if PGPASSWORD=$POSTGRES_PASSWORD psql -h $SLAVE_IP -U postgres -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ Connexion slave OK"
else
    echo "❌ Connexion slave échouée"
fi

echo ""
echo "📈 Monitoring repmgr terminé"
