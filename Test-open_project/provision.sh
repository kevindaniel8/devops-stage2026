#!/bin/bash

set -e
export DEBIAN_FRONTEND=noninteractive

echo "=== Mise à jour du système ==="
apt-get update -y
apt-get upgrade -y

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
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== Ajout de vagrant au groupe docker ==="
usermod -aG docker vagrant

echo "=== Création des volumes OpenProject ==="
mkdir -p /var/lib/openproject/pgdata
mkdir -p /var/lib/openproject/assets

echo "=== Lancement du conteneur OpenProject ==="
docker run -d \
  --name openproject \
  -p 8080:80 \
  -e OPENPROJECT_HOST__NAME=192.168.56.25 \
  -e OPENPROJECT_HTTPS=false \
  -e SECRET_KEY_BASE=secret \
  -v /var/lib/openproject/pgdata:/var/openproject/pgdata \
  -v /var/lib/openproject/assets:/var/openproject/assets \
  openproject/openproject:17

echo "=== Installation terminée ==="
