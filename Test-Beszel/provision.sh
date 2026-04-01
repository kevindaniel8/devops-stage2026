#!/bin/bash

############################################### installation docker officiel ##############################################

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


############################################################# Configuration DNS Docker #############################################################

echo "=== Configuration DNS Docker ==="

# Configuration DNS Docker
if ! grep -q "8.8.8.8" /etc/docker/daemon.json 2>/dev/null; then
  echo ">>> Mise à jour du DNS Docker"
  mkdir -p /etc/docker
  
  # Création du fichier daemon.json avec DNS
  cat <<EOF > /etc/docker/daemon.json
{
  "dns": ["8.8.8.8", "8.8.4.4"],
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
  
  echo ">>> Redémarrage de Docker"
  systemctl restart docker
  
  echo ">>> Attente du redémarrage Docker (10 secondes)"
  sleep 10
else
  echo ">>> DNS Docker déjà configuré"
fi

echo "=== Installation terminée ==="
