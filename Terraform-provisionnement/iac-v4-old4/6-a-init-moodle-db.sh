#!/bin/bash
# Script d'initialisation de la base PostgreSQL pour Moodle

set -e

# Détection du répertoire du script (chemin relatif)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="${SCRIPT_DIR}/ansible/inventories/dev/hosts.yml"

echo "🔧 Initialisation de la base PostgreSQL pour Moodle..."
echo "📁 Répertoire du script: ${SCRIPT_DIR}"
echo "📄 Inventory: ${INVENTORY_FILE}"

# Créer un fichier temporaire avec les commandes SQL
TMP_FILE=$(mktemp)
cat > "$TMP_FILE" << 'REMOTECMD'
# Créer la base et l'utilisateur
sudo -u postgres psql -c "CREATE DATABASE moodle WITH ENCODING='UTF8' LC_COLLATE='C.UTF-8' LC_CTYPE='C.UTF-8' TEMPLATE=template0;" 2>/dev/null || echo 'DB existe déjà'
sudo -u postgres psql -c "CREATE USER moodle WITH PASSWORD 'motdepasse';" 2>/dev/null || echo 'User existe déjà'
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE moodle TO moodle;"
sudo -u postgres psql -c "ALTER USER moodle WITH SUPERUSER;"

# Modification de pg_hba.conf pour autoriser les connexions
if ! grep -q "host    moodle    moodle    0.0.0.0/0    md5" /etc/postgresql/16/main/pg_hba.conf; then
    echo "host    moodle    moodle    0.0.0.0/0    md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf > /dev/null
fi

# Écouter sur toutes les interfaces
sudo sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/16/main/postgresql.conf 2>/dev/null || true
sudo sed -i "s/^listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/16/main/postgresql.conf 2>/dev/null || true

# Redémarrer PostgreSQL
sudo systemctl restart postgresql
REMOTECMD

# Copier et exécuter le script sur le serveur distant
ansible db-postgres-master -i "${INVENTORY_FILE}" -m copy -a "src=$TMP_FILE dest=/tmp/init-moodle-db.sh mode=0755"
ansible db-postgres-master -i "${INVENTORY_FILE}" -m shell -a "/tmp/init-moodle-db.sh"

# Nettoyer
rm -f "$TMP_FILE"
ansible db-postgres-master -i "${INVENTORY_FILE}" -m file -a "path=/tmp/init-moodle-db.sh state=absent"

echo "✅ Base de données Moodle créée !"
echo ""
echo "Informations de connexion :"
echo "  - Host: 192.168.20.20"
echo "  - Port: 5432"
echo "  - Database: moodle"
echo "  - User: moodle"
echo "  - Password: motdepasse"
