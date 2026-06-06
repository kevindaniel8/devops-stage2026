#!/bin/bash
set -e

echo "🚀 Initialisation Moodle..."

MOODLE_ROOT="/var/www/moodle"
MOODLE_DATA="/var/www/moodledata"
MOODLE_CONFIG="${MOODLE_ROOT}/config.php"

# ------------------------------------------------
# 1. Permissions (TOUJOURS root ici OK)
# ------------------------------------------------
echo "🔧 Permissions Moodledata..."

mkdir -p "${MOODLE_DATA}"
chown -R www-data:www-data "${MOODLE_DATA}"
chmod -R 775 "${MOODLE_DATA}"

echo "✔ permissions OK"

# ------------------------------------------------
# 2. Attente PostgreSQL
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

echo "✔ PostgreSQL OK"

# ------------------------------------------------
# 3. Test connexion DB (IMPORTANT DEBUG)
# ------------------------------------------------
echo "🔍 Test connexion DB PHP..."

php -r "
$conn = pg_connect(\"host=${MOODLE_DATABASE_HOST} port=${MOODLE_DATABASE_PORT_NUMBER} dbname=${MOODLE_DATABASE_NAME} user=${MOODLE_DATABASE_USER} password=${MOODLE_DATABASE_PASSWORD}\");
if (!$conn) {
    echo \"❌ DB FAIL\n\";
    exit(1);
}
echo \"✔ DB OK\n\";
"

# ------------------------------------------------
# 4. config.php
# ------------------------------------------------
if [ ! -f "${MOODLE_CONFIG}" ]; then
    echo "🛠 Création config.php..."

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
  'dbport' => '${MOODLE_DATABASE_PORT_NUMBER}',
);

\$CFG->wwwroot = '${MOODLE_WWWROOT}';
\$CFG->dataroot = '${MOODLE_DATA}';
\$CFG->admin = 'admin';

require_once(__DIR__ . '/lib/setup.php');
EOF

    chown www-data:www-data "${MOODLE_CONFIG}"
    echo "✔ config.php OK"
fi

# ------------------------------------------------
# 5. Installation Moodle (IMPORTANT: éviter boucle)
# ------------------------------------------------
if [ ! -f "${MOODLE_DATA}/installed.lock" ]; then

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
    --fullname='Moodle' \
    --shortname='Moodle' \
    --adminuser='admin' \
    --adminpass='Admin@123'
    "

    touch "${MOODLE_DATA}/installed.lock"
    echo "✔ Moodle installé"
else
    echo "ℹ️ Moodle déjà installé"
fi

# ------------------------------------------------
# 6. Cron
# ------------------------------------------------
echo "* * * * * www-data php ${MOODLE_ROOT}/admin/cli/cron.php >/dev/null 2>&1" > /etc/cron.d/moodle
chmod 0644 /etc/cron.d/moodle
service cron start

# ------------------------------------------------
# 7. Apache
# ------------------------------------------------
echo "🌐 Apache start..."
exec apache2-foreground