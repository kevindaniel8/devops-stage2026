#!/bin/bash
set -e

echo "🚀 Initialisation Moodle..."

MOODLE_DATA_DIR="/var/www/moodledata"
MOODLE_CONFIG="/var/www/moodle/config.php"
MOODLE_ROOT="/var/www/moodle"

# -----------------------------
# Attente PostgreSQL
# -----------------------------
echo "⏳ Attente PostgreSQL sur ${MOODLE_DATABASE_HOST}:${MOODLE_DATABASE_PORT_NUMBER}..."

until pg_isready -h "${MOODLE_DATABASE_HOST}" \
                 -p "${MOODLE_DATABASE_PORT_NUMBER}" \
                 -U "${MOODLE_DATABASE_USER}" >/dev/null 2>&1; do
    echo "PostgreSQL pas prêt..."
    sleep 2
done

echo "✅ PostgreSQL OK"

# -----------------------------
# moodledata
# -----------------------------
mkdir -p "${MOODLE_DATA_DIR}"
chown -R www-data:www-data "${MOODLE_DATA_DIR}"

# -----------------------------
# config.php
# -----------------------------
if [ ! -f "${MOODLE_CONFIG}" ]; then
    echo "🛠 Création config.php Moodle..."

    cat > "${MOODLE_CONFIG}" <<EOF
<?php
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

/* DATABASE */
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
    'dbport'    => '${MOODLE_DATABASE_PORT_NUMBER}'
];

/* PATHS */
\$CFG->wwwroot   = '${MOODLE_WWWROOT:-http://192.168.20.220:30081}';
\$CFG->dataroot  = '/var/www/moodledata';
\$CFG->dirroot   = '/var/www/moodle';
\$CFG->admin     = 'admin';

\$CFG->directorypermissions = 02777;
\$CFG->slasharguments = 1;

/* SECURITY */
\$CFG->sessioncookie = 'moodle';
\$CFG->cookieprefix = 'moodle_';

/* PERFORMANCE */
\$CFG->cachetype = 'internal';
\$CFG->themerev  = -1;
\$CFG->jsrev     = -1;

/* DEBUG OFF */
\$CFG->debug = 0;
\$CFG->debugdisplay = false;
EOF

    chown www-data:www-data "${MOODLE_CONFIG}"
    echo "✅ config.php créé"
fi

# -----------------------------
# Permissions Moodle
# -----------------------------
echo "🔧 Configuration permissions..."
# Ownership seulement sur les répertoires clés (pas de -R pour éviter les boucles sur liens symboliques)
chown www-data:www-data "${MOODLE_ROOT}"
chown -R www-data:www-data "${MOODLE_DATA_DIR}"
# S'assurer que le répertoire Moodle est accessible
find "${MOODLE_ROOT}" -maxdepth 2 -type d -exec chown www-data:www-data {} \; 2>/dev/null || true

# -----------------------------
# Vérification base de données
# -----------------------------
echo "🔍 Vérification connexion base de données..."
if ! sudo -u www-data php -r "
require '${MOODLE_CONFIG}';
\$conn = pg_connect(\"host=\$CFG->dbhost port=\$CFG->dboptions['dbport'] dbname=\$CFG->dbname user=\$CFG->dbuser password=\$CFG->dbpass\");
exit(\$conn ? 0 : 1);
" 2>/dev/null; then
    echo "❌ Impossible de se connecter à la base de données"
    echo "Vérifiez que PostgreSQL est accessible et que la base moodle existe"
    exit 1
fi
echo "✅ Connexion base de données OK"

# -----------------------------
# Installation CLI (si vide)
# -----------------------------
if [ ! -f "${MOODLE_DATA_DIR}/.installed" ]; then
    echo "⚙️ Installation Moodle..."

    cd "${MOODLE_ROOT}"

    # Vérifier si Moodle est déjà installé dans la base
    TABLES_EXIST=$(sudo -u www-data php -r "
        require '${MOODLE_CONFIG}';
        \$conn = pg_connect(\"host=\$CFG->dbhost port=\$CFG->dboptions['dbport'] dbname=\$CFG->dbname user=\$CFG->dbuser password=\$CFG->dbpass\");
        if (!\$conn) exit(1);
        \$res = pg_query(\$conn, \"SELECT 1 FROM pg_tables WHERE tablename='config' AND schemaname='public'\");
        exit(pg_num_rows(\$res) > 0 ? 0 : 1);
    " 2>/dev/null && echo "exists" || echo "")

    if [ "${TABLES_EXIST}" = "exists" ]; then
        echo "ℹ️ Tables Moodle déjà présentes dans la base"
    else
        sudo -u www-data php admin/cli/install.php \
            --non-interactive \
            --agree-license \
            --fullname="${MOODLE_SITE_NAME:-Moodle}" \
            --shortname="${MOODLE_SITE_NAME:-Moodle}" \
            --adminuser="${MOODLE_USERNAME:-admin}" \
            --adminpass="${MOODLE_PASSWORD:-Admin@123}" \
            --adminemail="${MOODLE_EMAIL:-admin@example.com}" \
            2>&1

        if [ $? -eq 0 ]; then
            echo "✅ Installation Moodle réussie"
        else
            echo "⚠️ Installation a retourné des erreurs (peut-être déjà installé)"
        fi
    fi

    touch "${MOODLE_DATA_DIR}/.installed"
    echo "✅ Installation terminée"
else
    echo "ℹ️ Moodle déjà installé (marqueur .installed présent)"
fi

# -----------------------------
# Apache
# -----------------------------
echo "🌐 Démarrage Apache..."
exec apache2-foreground