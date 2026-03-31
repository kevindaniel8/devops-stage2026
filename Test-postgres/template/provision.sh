#!/usr/bin/env bash

set -e
export DEBIAN_FRONTEND=noninteractive

echo "=== Mise à jour du système ==="
apt-get update -y
apt-get upgrade -y
apt-get install -y wget gnupg lsb-release

############################################ installation PostgreSQL ##############################################################

# Ajout du dépôt officiel PostgreSQL
wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
  > /etc/apt/sources.list.d/pgdg.list

# Installation PostgreSQL 16
apt-get update -y
apt-get install -y postgresql-16 postgresql-client-16

# Configuration des variables
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
DOCKER_USER=${DOCKER_USER:-vagrant}

# Définition du mot de passe postgres
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';"

# Fichiers de configuration
PG_VERSION=16
PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"

# Autoriser les connexions externes (configurable)
sed -i "s/^#listen_addresses =.*/listen_addresses = '*'/" $PG_CONF

# Autoriser les connexions locales et réseau (plus sécurisé que 0.0.0.0/0)
echo "host    all             all             0.0.0.0/0               md5" >> $PG_HBA

# Redémarrage avec vérification
echo "=== Redémarrage de PostgreSQL ==="
if systemctl restart postgresql; then
    echo "✓ PostgreSQL redémarré avec succès"
else
    echo "✗ Erreur lors du redémarrage de PostgreSQL"
    exit 1
fi

# Vérification que PostgreSQL est bien démarré
if systemctl is-active --quiet postgresql; then
    echo "✓ PostgreSQL est actif"
else
    echo "✗ PostgreSQL n'est pas démarré correctement"
    exit 1
fi

############################################ ajout de docker utile pour l'agent beszel ############################################


echo "=== Installation des dépendances Docker ==="
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

echo "=== Ajout de la clé GPG Docker ==="
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "=== Ajout du dépôt Docker officiel ==="
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
  $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

echo "=== Installation de Docker CE ==="
apt-get update -y
if apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
    echo "✓ Docker installé avec succès"
else
    echo "✗ Erreur lors de l'installation de Docker"
    exit 1
fi

echo "=== Ajout de $DOCKER_USER au groupe docker ==="
if usermod -aG docker $DOCKER_USER; then
    echo "✓ $DOCKER_USER ajouté au groupe docker"
else
    echo "✗ Erreur lors de l'ajout de $DOCKER_USER au groupe docker"
    exit 1
fi

# Vérification que Docker est bien installé et fonctionnel
echo "=== Vérification de Docker ==="
if systemctl is-active --quiet docker; then
    echo "✓ Docker est actif"
else
    echo "⚠ Docker n'est pas démarré, tentative de démarrage..."
    systemctl start docker
    if systemctl is-active --quiet docker; then
        echo "✓ Docker démarré avec succès"
    else
        echo "✗ Impossible de démarrer Docker"
        exit 1
    fi
fi

echo "=== Installation terminée avec succès ==="


