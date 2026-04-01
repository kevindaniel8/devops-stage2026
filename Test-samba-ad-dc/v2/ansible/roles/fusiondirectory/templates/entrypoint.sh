#!/bin/bash
set -e

# Démarrer Apache en arrière-plan
apache2ctl -D FOREGROUND &
APACHE_PID=$!

# Nettoyage cache (optionnel)
rm -rf /var/cache/fusiondirectory/*

# Attendre LDAP (évite crash au démarrage)
echo "Testing LDAP connection..."
if ldapsearch -x -H "$LDAP_SERVER" -b "$LDAP_BASE_DN" -D "$LDAP_BIND_DN" -w "$LDAP_BIND_PASSWORD" >/dev/null 2>&1; then
  echo "LDAP connection successful"
else
  echo "LDAP connection failed - but Apache is running"
fi

# Attendre Apache
wait $APACHE_PID

# Générer config UNIQUEMENT si absente
if [ ! -f /etc/fusiondirectory/config.php ]; then
  echo "Generating FusionDirectory config..."

  cat > /etc/fusiondirectory/config.php << EOF
<?php
\$config = array(
    'ldap' => array(
        'server' => '${LDAP_SERVER}',
        'base_dn' => '${LDAP_BASE_DN}',
        'admin_dn' => '${LDAP_BIND_DN}',
        'admin_password' => '${LDAP_BIND_PASSWORD}',
        'tls' => false,
        'sasl' => false
    ),
    'core' => array(
        'security_check' => false,
        'password_hash' => 'ssha',
        'timezone' => 'Europe/Paris',
        'debug_level' => 0,
        'session_timeout' => 1800,
        'cookie_lifetime' => 86400,
        'language' => 'fr_FR'
    )
);
?>
EOF

  chown www-data:www-data /etc/fusiondirectory/config.php
  chmod 640 /etc/fusiondirectory/config.php
fi

# Apache → bon dossier
sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/html|' /etc/apache2/sites-available/000-default.conf
sed -i 's|<Directory /var/www/html/>|<Directory /var/www/html/html/>|' /etc/apache2/sites-available/000-default.conf

# Autoriser .htaccess
sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

# Permissions cache
chown -R www-data:www-data /var/cache/fusiondirectory
chmod 755 /var/cache/fusiondirectory

exec "$@"