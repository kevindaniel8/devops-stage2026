#!/usr/bin/env bash

set -e
export DEBIAN_FRONTEND=noninteractive

echo "=== Provision MASTER PostgreSQL avec repmgr (idempotent) ==="

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
PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"

# Configuration mot de passe postgres
echo "🔧 Configuration mot de passe postgres..."
export PGPASSWORD=$POSTGRES_PASSWORD
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';" 2>/dev/null || echo "✅ Mot de passe déjà configuré"

# Créer user repmgr (si n'existe pas) - avec droits étendus selon article
echo "👤 Création user repmgr avec droits étendus..."
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='repmgr'" | grep -q 1; then
    sudo -u postgres createuser --replication --createdb --createrole --superuser repmgr
    sudo -u postgres psql -c "ALTER USER repmgr PASSWORD '$REPMGR_PASSWORD';"
    sudo -u postgres psql -c "ALTER USER repmgr SET search_path TO repmgr, \"\$user\", public;"
    echo "✅ User repmgr créé avec droits étendus"
else
    echo "✅ User repmgr déjà existe"
    # Mettre à jour les permissions si existant
    sudo -u postgres psql -c "ALTER USER repmgr SET search_path TO repmgr, \"\$user\", public;"
fi

# Créer la base repmgr
echo "🗄️  Création de la base repmgr..."
sudo -u postgres createdb repmgr --owner=repmgr 2>/dev/null || echo "✅ Base repmr déjà existe"

# Installer l'extension repmgr dans la base repmgr
echo "🔧 Installation de l'extension repmgr..."
sudo -u postgres psql -d repmgr -c "CREATE EXTENSION IF NOT EXISTS repmgr;" 2>/dev/null || echo "✅ Extension repmgr déjà installée"

# Vérifier que l'extension est bien installée
if sudo -u postgres psql -d repmgr -c "SELECT extname FROM pg_extension WHERE extname='repmgr';" | grep -q repmgr; then
    echo "✅ Extension repmgr installée avec succès"
else
    echo "❌ Extension repmgr non installée"
    exit 1
fi

# Pas besoin de permissions spécifiques car repmgr est superuser
echo "✅ Permissions repmgr (superuser) déjà configurées"

# Configuration listen_addresses
if ! grep -q "^listen_addresses = '\*'" $PG_CONF; then
    echo "🔧 Configuration listen_addresses..."
    sed -i "s/^#listen_addresses =.*/listen_addresses = '*'/" $PG_CONF
else
    echo "✅ listen_addresses déjà configuré"
fi

# Configuration pg_hba.conf
if ! grep -q "host.*all.*all.*0.0.0.0/0.*md5" $PG_HBA; then
    echo "host    all             all             0.0.0.0/0           md5" >> $PG_HBA
    echo "✅ Accès général configuré"
else
    echo "✅ Accès général déjà configuré"
fi

# Configuration pg_hba.conf pour repmgr
if ! grep -q "host.*repmgr.*repmgr.*$SLAVE_IP/32.*md5" $PG_HBA; then
    echo "host    replication     repmgr          $SLAVE_IP/32          md5" >> $PG_HBA
    echo "host    repmgr          repmgr          $SLAVE_IP/32          md5" >> $PG_HBA
    echo "✅ Accès repmgr configuré"
else
    echo "✅ Accès repmgr déjà configuré"
fi

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

# Dossier archive
if [ ! -d /var/lib/postgresql/wal_archive ]; then
    mkdir -p /var/lib/postgresql/wal_archive
    chown postgres:postgres /var/lib/postgresql/wal_archive
    echo "✅ Dossier archive créé"
else
    echo "✅ Dossier archive déjà existe"
fi

# Configuration repmgr.conf
echo "⚙️  Configuration repmgr.conf..."
REPMGR_CONF="/etc/repmgr/16/repmgr.conf"
if [ ! -f $REPMGR_CONF ]; then
    mkdir -p /etc/repmgr/16
    cat > $REPMGR_CONF << EOF
node_id=1
node_name=node1
conninfo='host=$MASTER_IP port=5432 user=repmgr dbname=repmgr connect_timeout=2 password=$REPMGR_PASSWORD'
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

# Redémarrage PostgreSQL si nécessaire
if systemctl is-active --quiet postgresql@16-main; then
    echo "🔄 PostgreSQL déjà actif, redémarrage pour appliquer config..."
    systemctl restart postgresql@16-main
else
    echo "🚀 Démarrage PostgreSQL..."
    systemctl start postgresql@16-main
fi

# Enregistrer le master
echo "📝 Enregistrement du master..."
export PGPASSWORD=$REPMGR_PASSWORD
if ! sudo -u postgres PGPASSWORD=$REPMGR_PASSWORD repmgr -f $REPMGR_CONF primary register > /dev/null 2>&1; then
    echo "⚠️  Master déjà enregistré ou erreur"
else
    echo "✅ Master enregistré avec succès"
fi

echo "✅ Master repmgr configuré avec succès"
echo "IP: $MASTER_IP"
echo "Repmgr password: $REPMGR_PASSWORD"
