#!/usr/bin/env bash

set -e
export DEBIAN_FRONTEND=noninteractive

echo "=== Provision SLAVE PostgreSQL avec repmgr (idempotent) ==="

# Variables
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
REPMGR_PASSWORD=${REPMGR_PASSWORD:-repmgr_password}
MASTER_IP="192.168.56.21"
SLAVE_IP="192.168.56.22"
REPMGR_PORT=5432

# Vérifier si PostgreSQL est déjà installé
if ! command -v psql > /dev/null 2>&1; then
    echo "📦 Installation PostgreSQL..."
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y wget gnupg lsb-release

    # PostgreSQL
    wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
    apt-get update -y
    apt-get install -y postgresql-16 postgresql-client-16
else
    echo "✅ PostgreSQL déjà installé"
fi

# Installation de repmgr
if ! command -v repmgr > /dev/null 2>&1; then
    echo "📦 Installation de repmgr..."
    apt-get install -y postgresql-16-repmgr
else
    echo "✅ repmgr déjà installé"
fi

# Configuration PostgreSQL
PG_VERSION=16
PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

# Configuration mot de passe postgres
echo "🔧 Configuration mot de passe postgres..."
export PGPASSWORD=$POSTGRES_PASSWORD
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';" 2>/dev/null || echo "✅ Mot de passe déjà configuré"

# Configuration réplication (vérifier chaque paramètre)
echo "🔧 Configuration réplication..."
REPLICATION_CONFIG="
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
wal_keep_size = 2GB
archive_mode = on
archive_command = 'test ! -f /var/lib/postgresql/wal_archive/%f && cp %p /var/lib/postgresql/wal_archive/%f'
shared_preload_libraries = 'repmgr'
"

while IFS= read -r line; do
    if [ ! -z "$line" ] && [[ ! "$line" == \#* ]]; then
        param=$(echo "$line" | cut -d'=' -f1 | xargs)
        if ! grep -q "^$param\s*=" $PG_CONF; then
            echo "$line" >> $PG_CONF
            echo "✅ Ajouté: $param"
        else
            echo "✅ $param déjà configuré"
        fi
    fi
done <<< "$REPLICATION_CONFIG"

# Corriger shared_preload_libraries si c'est l'ancienne version
if grep -q "shared_preload_libraries = 'repmgr_funcs'" $PG_CONF; then
    echo "🔧 Correction de shared_preload_libraries..."
    sed -i "s/shared_preload_libraries = 'repmgr_funcs'/shared_preload_libraries = 'repmgr'/" $PG_CONF
    echo "✅ shared_preload_libraries corrigé"
fi

# Configuration listen_addresses
if ! grep -q "^listen_addresses = '\*'" $PG_CONF; then
    echo "🔧 Configuration listen_addresses..."
    sed -i "s/^#listen_addresses =.*/listen_addresses = '*'/" $PG_CONF
else
    echo "✅ listen_addresses déjà configuré"
fi

if ! grep -q "host.*all.*all.*0.0.0.0/0.*md5" $PG_HBA; then
    echo "host    all             all             0.0.0.0/0           md5" >> $PG_HBA
    echo "✅ Accès général configuré"
else
    echo "✅ Accès général déjà configuré"
fi

# Configuration pg_hba.conf pour repmgr
if ! grep -q "host.*repmgr.*repmgr.*$MASTER_IP/32.*md5" $PG_HBA; then
    echo "host    replication     repmgr          $MASTER_IP/32         md5" >> $PG_HBA
    echo "host    repmgr          repmgr          $MASTER_IP/32         md5" >> $PG_HBA
    echo "✅ Accès repmgr configuré"
else
    echo "✅ Accès repmgr déjà configuré"
fi

# Configuration repmgr.conf
echo "⚙️  Configuration repmgr.conf..."
REPMGR_CONF="/etc/repmgr/16/repmgr.conf"
if [ ! -f $REPMGR_CONF ]; then
    mkdir -p /etc/repmgr/16
    cat > $REPMGR_CONF << EOF
node_id=2
node_name=node2
conninfo='host=$SLAVE_IP port=5432 user=repmgr dbname=repmgr connect_timeout=2 password=$REPMGR_PASSWORD'
data_directory='/var/lib/postgresql/16/main'
pg_bindir='/usr/lib/postgresql/16/bin'
use_replication_slots=1
monitoring_history=true
monitor_interval_secs=2
reconnect_attempts=6
reconnect_interval=5
failover=automatic
promote_command='/usr/bin/repmgr standby promote -f /etc/repmgr/16/repmgr.conf --dry-run'
follow_command='/usr/bin/repmgr standby follow -f /etc/repmgr/16/repmgr.conf'
EOF
    chown postgres:postgres $REPMGR_CONF
    echo "✅ Fichier repmgr.conf créé"
else
    echo "✅ Fichier repmgr.conf existe déjà"
fi

# Vérifier si déjà configuré en slave
if [ -f /var/lib/postgresql/16/main/standby.signal ]; then
    echo "✅ Slave déjà configuré, vérification de la réplication..."
    
    # Vérifier si PostgreSQL tourne
    if ! systemctl is-active --quiet postgresql@16-main; then
        echo "⚠️  PostgreSQL arrêté, redémarrage..."
        systemctl start postgresql@16-main
        sleep 5
    fi
    
    # Vérifier si PostgreSQL est prêt
    if ! pg_isready -h localhost -U postgres > /dev/null 2>&1; then
        echo "⚠️  PostgreSQL pas prêt, attente 10s..."
        sleep 10
        if ! pg_isready -h localhost -U postgres > /dev/null 2>&1; then
            echo "❌ PostgreSQL ne démarre pas - reconfiguration complète..."
            rm -f /var/lib/postgresql/16/main/standby.signal
            systemctl stop postgresql@16-main
        fi
    fi
    
    # Vérifier si la réplication fonctionne
    RECOVERY_MODE=$(sudo -u postgres psql -tAc "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d ' ')
    if [ "$RECOVERY_MODE" = "t" ]; then
        echo "✅ Slave en mode recovery"
        
        # Vérifier si la réplication est active (timeout de 10 secondes)
        echo "🔍 Vérification de la connexion de réplication..."
        if timeout 10 sudo -u postgres psql -tAc "SELECT 1 FROM pg_stat_wal_receiver;" > /dev/null 2>&1; then
            echo "✅ Réplication active"
            
            # Vérifier le lag (avec gestion d'erreur)
            LAG_BYTES=$(timeout 5 sudo -u postgres psql -tAc "SELECT pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn());" 2>/dev/null | tr -d ' ')
            if [ -n "$LAG_BYTES" ] && [ "$LAG_BYTES" -gt 0 ] 2>/dev/null; then
                echo "⏱️  Lag de réplication: $LAG_BYTES bytes"
            else
                echo "✅ Réplication à jour"
            fi
        else
            echo "⚠️  Slave en recovery mais réplication inactive - reconfiguration nécessaire..."
            # Forcer la reconfiguration
            rm -f /var/lib/postgresql/16/main/standby.signal
            systemctl stop postgresql@16-main
        fi
    else
        echo "⚠️  Slave configuré mais pas en mode recovery - reconfiguration complète..."
        rm -f /var/lib/postgresql/16/main/standby.signal
        systemctl stop postgresql@16-main
    fi
    
    # Si on arrive ici, c'est que tout est OK
    if systemctl is-active --quiet postgresql@16-main && [ -f /var/lib/postgresql/16/main/standby.signal ]; then
        echo "✅ Slave déjà configuré et fonctionnel"
        echo "IP: $SLAVE_IP"
        echo "Réplication depuis: $MASTER_IP"
        exit 0
    fi
else
    echo "🔄 Configuration de la réplication depuis le master..."
    
    # Attendre que master soit prêt (avec timeout)
    echo "⏳ Attente du master..."
    TIMEOUT=60  # 60 secondes max
    COUNT=0
    while ! pg_isready -h $MASTER_IP -U postgres > /dev/null 2>&1; do
        if [ $COUNT -ge $TIMEOUT ]; then
            echo "❌ Timeout: Master non disponible après $TIMEOUT secondes"
            exit 1
        fi
        echo "Master pas encore prêt, attente 10s... ($COUNT/$TIMEOUT)"
        sleep 10
        COUNT=$((COUNT + 10))
    done

    # Arrêter PostgreSQL
    systemctl stop postgresql@16-main || true

    # Nettoyer les données existantes
    rm -rf /var/lib/postgresql/16/main/*

    # Créer le répertoire avec bonnes permissions
    mkdir -p /var/lib/postgresql/16/main
    chown postgres:postgres /var/lib/postgresql/16/main
    chmod 700 /var/lib/postgresql/16/main

    # Clonage avec repmgr (avec vérification)
    echo "📦 Clonage depuis master avec repmgr..."
    export PGPASSWORD=$REPMGR_PASSWORD
    
    # Test de connexion avant clonage
    if ! psql -h $MASTER_IP -U repmgr -d repmgr -c "SELECT 1;" > /dev/null 2>&1; then
        echo "❌ Échec de connexion au master pour clonage"
        exit 1
    fi
    
    # Vérifier si le master est enregistré dans repmgr
    echo "🔍 Vérification de l'enregistrement du master..."
    MASTER_NODES=$(psql -h $MASTER_IP -U repmgr -d repmgr -tAc "SELECT COUNT(*) FROM repmgr.nodes WHERE type = 'primary' AND active IS TRUE;" 2>/dev/null | tr -d ' ')
    
    if [ "$MASTER_NODES" -eq 0 ]; then
        echo "⚠️  Master non enregistré dans repmgr, tentative d'enregistrement..."
        # Tenter d'enregistrer le master depuis le slave (si possible)
        if ! ssh -o StrictHostKeyChecking=no postgres@$MASTER_IP "repmgr -f /etc/repmgr/16/repmgr.conf primary register" > /dev/null 2>&1; then
            echo "❌ Impossible d'enregistrer le master à distance"
            echo "💡 Veuillez exécuter sur le master :"
            echo "   sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf primary register"
            exit 1
        fi
        echo "✅ Master enregistré avec succès"
        sleep 2  # Attendre que l'enregistrement soit propagé
    fi
    
    # Clonage réel
    echo "🔐 Configuration de l'environnement pour repmgr..."
    export PGPASSWORD=$REPMGR_PASSWORD
    
    # Créer un fichier .pgpass temporaire pour repmgr
    echo "192.168.56.21:5432:repmgr:repmgr:$REPMGR_PASSWORD" | sudo -u postgres tee /var/lib/postgresql/.pgpass > /dev/null
    sudo chmod 600 /var/lib/postgresql/.pgpass
    sudo chown postgres:postgres /var/lib/postgresql/.pgpass
    
    # Clonage avec repmgr
    if ! sudo -u postgres PGPASSWORD=$REPMGR_PASSWORD repmgr -f $REPMGR_CONF standby clone -h $MASTER_IP -U repmgr -d repmgr --verbose; then
        echo "❌ Échec du clonage depuis master"
        # Nettoyer le fichier .pgpass
        sudo rm -f /var/lib/postgresql/.pgpass
        exit 1
    fi
    
    # Nettoyer le fichier .pgpass
    sudo rm -f /var/lib/postgresql/.pgpass
    echo "✅ Clonage terminé"

    # Vérifier que les données sont bien là
    if [ ! -f /var/lib/postgresql/16/main/PG_VERSION ]; then
        echo "❌ Le clonage n'a pas créé de données valides"
        exit 1
    fi

    # Démarrer PostgreSQL
    echo "🚀 Démarrage PostgreSQL slave..."
    if ! systemctl start postgresql@16-main; then
        echo "❌ Échec du démarrage de PostgreSQL"
        exit 1
    fi

    # Attendre que PostgreSQL soit prêt (avec timeout)
    echo "⏳ Attente que PostgreSQL slave soit prêt..."
    TIMEOUT=30
    COUNT=0
    while ! pg_isready -h localhost -U postgres > /dev/null 2>&1; do
        if [ $COUNT -ge $TIMEOUT ]; then
            echo "❌ Timeout: PostgreSQL slave non prêt après $TIMEOUT secondes"
            exit 1
        fi
        echo "PostgreSQL slave pas encore prêt, attente 5s... ($COUNT/$TIMEOUT)"
        sleep 5
        COUNT=$((COUNT + 5))
    done

    # Vérification finale de la réplication
    echo "🔍 Vérification finale de la réplication..."
    RECOVERY_MODE=$(sudo -u postgres psql -tAc "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d ' ')
    if [ "$RECOVERY_MODE" = "t" ]; then
        echo "✅ Slave configuré avec succès et en mode recovery"
    else
        echo "❌ Slave configuré mais pas en mode recovery"
        exit 1
    fi

    # Enregistrer le slave (si pas déjà enregistré)
    echo "📝 Enregistrement du slave..."
    if ! sudo -u postgres repmgr -f $REPMGR_CONF standby register > /dev/null 2>&1; then
        # Vérifier si déjà enregistré
        if sudo -u postgres repmgr -f $REPMGR_CONF standby status > /dev/null 2>&1; then
            echo "✅ Slave déjà enregistré"
        else
            echo "⚠️  Erreur d'enregistrement du slave"
        fi
    else
        echo "✅ Slave enregistré avec succès"
    fi
fi

# Vérification finale
if pg_isready -h localhost -U postgres > /dev/null 2>&1; then
    echo "✅ PostgreSQL slave fonctionnel"
else
    echo "❌ PostgreSQL slave ne fonctionne pas"
    exit 1
fi

# Vérification finale du service
if systemctl is-active --quiet postgresql@16-main; then
    echo "✅ Service PostgreSQL@16-main actif"
else
    echo "❌ Service PostgreSQL@16-main inactif"
    exit 1
fi

echo "✅ Slave repmgr configuré avec succès"
echo "IP: $SLAVE_IP"
echo "Réplication depuis: $MASTER_IP"
