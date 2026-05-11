#!/bin/bash
set -e

# Configuration Moodle via variables d'environnement
MOODLE_DATA_DIR="/var/www/moodledata"
MOODLE_CONFIG="/var/www/moodle/config.php"

# Attendre que PostgreSQL soit accessible
echo "Attente de PostgreSQL sur ${MOODLE_DATABASE_HOST}:${MOODLE_DATABASE_PORT_NUMBER}..."
until pg_isready -h "${MOODLE_DATABASE_HOST}" -p "${MOODLE_DATABASE_PORT_NUMBER}" -U "${MOODLE_DATABASE_USER}" 2>/dev/null; do
    echo "PostgreSQL n'est pas encore prêt..."
    sleep 2
done
echo "✅ PostgreSQL est accessible !"

# Créer le répertoire moodledata s'il n'existe pas
mkdir -p "${MOODLE_DATA_DIR}"
chown -R www-data:www-data "${MOODLE_DATA_DIR}"

# Générer le fichier config.php s'il n'existe pas
if [ ! -f "${MOODLE_CONFIG}" ]; then
    echo "Génération du fichier config.php..."
    
    cat > "${MOODLE_CONFIG}" <<EOF
<?php
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

// Base de données
\$CFG->dbtype    = '${MOODLE_DATABASE_TYPE}';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = '${MOODLE_DATABASE_HOST}';
\$CFG->dbname    = '${MOODLE_DATABASE_NAME}';
\$CFG->dbuser    = '${MOODLE_DATABASE_USER}';
\$CFG->dbpass    = '${MOODLE_DATABASE_PASSWORD}';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = [
    'dbpersist' => false,
    'dbsocket'  => false,
    'dbport'    => '${MOODLE_DATABASE_PORT_NUMBER}',
    'dbhandlesoptions' => false,
    'dbfailover' => false,
];

// Répertoire de données
\$CFG->dataroot  = '${MOODLE_DATA_DIR}';
\$CFG->directorypermissions = 02777;

// URL du site
\$CFG->wwwroot   = '${MOODLE_WWWROOT:-http://localhost:8080}';
\$CFG->admin     = 'admin';

// Sécurité
\$CFG->passwordsaltmain = '$(openssl rand -base64 32)';
\$CFG->sessioncookie = 'moodle';

// Performance
\$CFG->cachetype = 'internal';
\$CFG->themerev  = -1;
\$CFG->jsrev     = -1;

// Debug (désactivé en production)
\$CFG->debug     = 0;
\$CFG->debugdisplay = false;

// Inclusion finale
require_once(__DIR__ . '/lib/setup.php');
EOF
    
    chown www-data:www-data "${MOODLE_CONFIG}"
    echo "✅ config.php créé !"
    
    # Installation de Moodle via CLI
    echo "Installation de Moodle..."
    cd /var/www/moodle
    sudo -u www-data php admin/cli/install.php \
        --lang=fr \
        --fullname="${MOODLE_SITE_NAME:-Moodle}" \
        --shortname="${MOODLE_SITE_NAME:-Moodle}" \
        --adminuser="${MOODLE_USERNAME:-admin}" \
        --adminpass="${MOODLE_PASSWORD:-Admin@123}" \
        --adminemail="${MOODLE_EMAIL:-admin@example.com}" \
        --non-interactive \
        --agree-license \
        --allow-unstable \
        2>/dev/null || true
    
    echo "✅ Moodle installé !"
else
    echo "config.php existe déjà, skip installation"
fi

# Démarrer Apache
exec apache2-foreground
