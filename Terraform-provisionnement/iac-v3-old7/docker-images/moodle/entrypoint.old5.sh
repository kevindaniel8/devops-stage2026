#!/bin/bash
set -e

echo "🚀 Initialisation Moodle..."

MOODLE_ROOT="/var/www/moodle"
MOODLE_DATA="/var/www/moodledata"
MOODLE_CONFIG="${MOODLE_ROOT}/config.php"

# ------------------------------------------------
# Attente PostgreSQL
# ------------------------------------------------
echo "⏳ Attente PostgreSQL..."

until pg_isready \
    -h "${MOODLE_DATABASE_HOST}" \
    -p "${MOODLE_DATABASE_PORT_NUMBER}" \
    -U "${MOODLE_DATABASE_USER}" >/dev/null 2>&1
do
    echo "PostgreSQL non prêt..."
    sleep 2
done

echo "✅ PostgreSQL OK"

# ------------------------------------------------
# Permissions
# ------------------------------------------------
mkdir -p "${MOODLE_DATA}"

chown -R www-data:www-data "${MOODLE_DATA}"
chmod -R 775 "${MOODLE_DATA}"

# ------------------------------------------------
# config.php
# ------------------------------------------------
if [ ! -f "${MOODLE_CONFIG}" ]; then

cat > "${MOODLE_CONFIG}" <<EOF
<?php

unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype = 'pgsql';
\$CFG->dblibrary = 'native';

\$CFG->dbhost = '${MOODLE_DATABASE_HOST}';
\$CFG->dbname = '${MOODLE_DATABASE_NAME}';
\$CFG->dbuser = '${MOODLE_DATABASE_USER}';
\$CFG->dbpass = '${MOODLE_DATABASE_PASSWORD}';
\$CFG->prefix = 'mdl_';

\$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => '${MOODLE_DATABASE_PORT_NUMBER}',
);

\$CFG->wwwroot = '${MOODLE_WWWROOT}';
\$CFG->dataroot = '${MOODLE_DATA}';
\$CFG->admin = 'admin';

\$CFG->directorypermissions = 02777;

require_once(__DIR__ . '/lib/setup.php');
EOF

chown www-data:www-data "${MOODLE_CONFIG}"

echo "✅ config.php créé"
fi

# ------------------------------------------------
# Vérification DB
# ------------------------------------------------
echo "🔍 Vérification PostgreSQL..."

php -r "
\$conn = pg_connect(
'host=${MOODLE_DATABASE_HOST}
port=${MOODLE_DATABASE_PORT_NUMBER}
dbname=${MOODLE_DATABASE_NAME}
user=${MOODLE_DATABASE_USER}
password=${MOODLE_DATABASE_PASSWORD}'
);
exit(\$conn ? 0 : 1);
"

echo "✅ Connexion PostgreSQL OK"

# ------------------------------------------------
# Installation Moodle
# ------------------------------------------------
if ! php "${MOODLE_ROOT}/admin/cli/isinstalled.php"; then

echo "⚙️ Installation Moodle..."

su -s /bin/bash www-data -c "
php ${MOODLE_ROOT}/admin/cli/install.php \
--non-interactive \
--agree-license \
--lang=fr \
--wwwroot='${MOODLE_WWWROOT}' \
--dataroot='${MOODLE_DATA}' \
--dbtype='pgsql' \
--dbhost='${MOODLE_DATABASE_HOST}' \
--dbname='${MOODLE_DATABASE_NAME}' \
--dbuser='${MOODLE_DATABASE_USER}' \
--dbpass='${MOODLE_DATABASE_PASSWORD}' \
--fullname='${MOODLE_SITE_NAME:-Moodle}' \
--shortname='Moodle' \
--adminuser='${MOODLE_USERNAME:-admin}' \
--adminpass='${MOODLE_PASSWORD:-Admin@123}' \
--adminemail='${MOODLE_EMAIL:-admin@example.com}'
"

echo "✅ Moodle installé"

else
    echo "ℹ️ Moodle déjà installé"
fi

# ------------------------------------------------
# Cron Moodle
# ------------------------------------------------
echo "* * * * * www-data php ${MOODLE_ROOT}/admin/cli/cron.php >/dev/null 2>&1" > /etc/cron.d/moodle

chmod 0644 /etc/cron.d/moodle
crontab /etc/cron.d/moodle

service cron start

# ------------------------------------------------
# Apache
# ------------------------------------------------
echo "🌐 Démarrage Apache..."

exec apache2-foreground