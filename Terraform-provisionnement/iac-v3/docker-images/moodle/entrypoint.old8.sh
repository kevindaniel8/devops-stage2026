#!/bin/bash
set -e

# =========================================================
# 01 - Variables
# =========================================================

echo "🚀 Initialisation Moodle..."

MOODLE_ROOT="/var/www/moodle"
MOODLE_DATA="/var/www/moodledata"
MOODLE_CONFIG="${MOODLE_ROOT}/config.php"

DB_HOST="${MOODLE_DATABASE_HOST}"
DB_PORT="${MOODLE_DATABASE_PORT_NUMBER:-5432}"
DB_NAME="${MOODLE_DATABASE_NAME}"
DB_USER="${MOODLE_DATABASE_USER}"
DB_PASS="${MOODLE_DATABASE_PASSWORD}"

WWWROOT="${MOODLE_WWWROOT:-http://localhost}"

# =========================================================
# 02 - Vérification variables obligatoires
# =========================================================

if [ -z "${DB_HOST}" ] || \
   [ -z "${DB_NAME}" ] || \
   [ -z "${DB_USER}" ] || \
   [ -z "${DB_PASS}" ]; then

    echo "❌ Variables PostgreSQL manquantes"
    exit 1
fi

# =========================================================
# 03 - Attente PostgreSQL
# =========================================================

echo "⏳ Attente PostgreSQL sur ${DB_HOST}:${DB_PORT}..."

until pg_isready \
    -h "${DB_HOST}" \
    -p "${DB_PORT}" \
    -U "${DB_USER}" >/dev/null 2>&1
do
    echo "PostgreSQL non prêt..."
    sleep 2
done

echo "✅ PostgreSQL OK"

# =========================================================
# 04 - Création dossiers
# =========================================================

mkdir -p "${MOODLE_DATA}"

# =========================================================
# 04b - Structure public/ pour Moodle 5.2
# =========================================================

PUBLIC_DIR="${MOODLE_ROOT}/public"

if [ ! -d "${PUBLIC_DIR}" ]; then
    echo "📁 Création structure public/ pour Moodle 5.2..."
    
    # Créer le répertoire public
    mkdir -p "${PUBLIC_DIR}"
    
    # Créer l'index.php public pour Moodle 5.2
    cat > "${PUBLIC_DIR}/index.php" <<'EOFPUBLIC'
<?php
// Entry point for Moodle 5.2 public directory structure
// Change to parent directory so all relative includes work
chdir(dirname(__DIR__));
require_once('config.php');
require_once('lib/setup.php');

// Redirect to the main Moodle index logic
// (do NOT include index.php from parent - it throws rootdirpublic exception)
redirect(new moodle_url('/'));
EOFPUBLIC
    
    # Créer des liens symboliques pour les ressources statiques
    for dir in lib course mod blocks admin theme pix login backup calendar completion; do
        if [ -d "${MOODLE_ROOT}/${dir}" ] && [ ! -e "${PUBLIC_DIR}/${dir}" ]; then
            ln -s "../${dir}" "${PUBLIC_DIR}/${dir}" 2>/dev/null || true
        fi
    done
    
    chown -R www-data:www-data "${PUBLIC_DIR}"
    echo "✅ Structure public/ créée"
fi

# =========================================================
# 05 - Permissions
# =========================================================

echo "🔧 Configuration permissions..."

chown -R www-data:www-data "${MOODLE_DATA}"

echo "STEP 3 OK"

chmod -R 775 "${MOODLE_DATA}" || true

echo "✅ Permissions OK"




# =========================================================
# 06 - Génération config.php
# =========================================================

if [ ! -f "${MOODLE_CONFIG}" ]; then

    echo "🛠 Création config.php..."

cat > "${MOODLE_CONFIG}" <<EOF
<?php

unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

# ------------------------------------------------
# DATABASE
# ------------------------------------------------

\$CFG->dbtype = 'pgsql';
\$CFG->dblibrary = 'native';

\$CFG->dbhost = '${DB_HOST}';
\$CFG->dbname = '${DB_NAME}';
\$CFG->dbuser = '${DB_USER}';
\$CFG->dbpass = '${DB_PASS}';
\$CFG->prefix = 'mdl_';

\$CFG->dboptions = array (
    'dbpersist' => 0,
    'dbport' => '${DB_PORT}',
    'dbsocket' => '',
);

# ------------------------------------------------
# PATHS
# ------------------------------------------------

\$CFG->wwwroot = '${WWWROOT}';
\$CFG->dataroot = '${MOODLE_DATA}';
\$CFG->dirroot = '${MOODLE_ROOT}';
\$CFG->libdir = $CFG->dirroot . '/lib';
\$CFG->admin = 'admin';

# ------------------------------------------------
# SECURITY
# ------------------------------------------------

\$CFG->directorypermissions = 02777;

#require_once(__DIR__ . '/lib/setup.php'); # ne pas utiliser lors du deployement
EOF

    chown www-data:www-data "${MOODLE_CONFIG}"
    chmod 640 "${MOODLE_CONFIG}"

    echo "✅ config.php créé"

else
    echo "ℹ️ config.php déjà présent"
fi

# =========================================================
# 07 - Vérification connexion PostgreSQL
# =========================================================

echo "🔍 Vérification connexion PostgreSQL..."

if ! php -r "
\$conn = pg_connect('host=${DB_HOST} port=${DB_PORT} dbname=${DB_NAME} user=${DB_USER} password=${DB_PASS}');
if (!\$conn) { echo 'DB_FAIL'; exit(1); }
echo 'DB_OK';
exit(0);
" 2>/dev/null | grep -q 'DB_OK'; then
    echo "⚠️ Test connexion échoué (normal si DB non initialisée)"
else
    echo "✅ Connexion PostgreSQL OK"
fi

# =========================================================
# 08 - Vérification installation Moodle
# =========================================================

echo "🔍 Vérification installation Moodle..."

if ! su -s /bin/bash www-data -c \
    "php ${MOODLE_ROOT}/admin/cli/isinstalled.php" \
    >/dev/null 2>&1; then

    echo "⚙️ Installation Moodle..."

    su -s /bin/bash www-data -c "
    php ${MOODLE_ROOT}/admin/cli/install.php \
        --non-interactive \
        --agree-license \
        --lang=fr \
        --wwwroot='${WWWROOT}' \
        --dataroot='${MOODLE_DATA}' \
        --dbtype='pgsql' \
        --dbhost='${DB_HOST}' \
        --dbname='${DB_NAME}' \
        --dbuser='${DB_USER}' \
        --dbpass='${DB_PASS}' \
        --fullname='${MOODLE_SITE_NAME:-Moodle}' \
        --shortname='Moodle' \
        --adminuser='${MOODLE_USERNAME:-admin}' \
        --adminpass='${MOODLE_PASSWORD:-Admin@123}' \
        --adminemail='${MOODLE_EMAIL:-admin@example.com}'
    " && echo "✅ Moodle installé" || echo "⚠️ Installation a échoué ou déjà existante"

else
    echo "ℹ️ Moodle déjà installé"
fi

# =========================================================
# 09 - Configuration cron Moodle
# =========================================================

echo "🕒 Configuration cron Moodle..."

cat > /etc/cron.d/moodle <<EOF
* * * * * www-data php ${MOODLE_ROOT}/admin/cli/cron.php >/dev/null 2>&1
EOF

chmod 0644 /etc/cron.d/moodle
crontab /etc/cron.d/moodle

echo "✅ Cron configuré"

# =========================================================
# 10 - Démarrage cron
# =========================================================

echo "🚀 Démarrage cron..."

cron

# =========================================================
# 11 - Démarrage Apache
# =========================================================

echo "🌐 Démarrage Apache..."

exec apache2-foreground