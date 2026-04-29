#!/bin/bash
set -euo pipefail

############################################
# CONFIG
############################################
PROXMOX_HOST="192.168.0.1"
PROXMOX_USER="root"

SCRIPT1="./1-generate-ssh-keys.sh"
SCRIPT2="./2-create-user-proxmox.sh"
SCRIPT3="./3-cloud-init-images.sh"
SCRIPT4="./4-template-generique.sh"

SSH_KEY_PATH="./ssh/id_ed25519_terraform-proxmox.pub"

# Argument pour le script 3 (debian, 24.04, 26.04, ou all)
SCRIPT3_ARG="${1:-all}"
#SCRIPT3_ARG="${1:-debian}"

REMOTE_DIR="/home/kevin-stage-devops"
REMOTE_SCRIPT2="$REMOTE_DIR/2-create-user-proxmox.sh"
REMOTE_SCRIPT3="$REMOTE_DIR/3-cloud-init-images.sh"
REMOTE_SCRIPT4="$REMOTE_DIR/4-template-generique.sh"

############################################
# SSH MULTIPLEXING
############################################
SSH_CTRL_DIR="$HOME/.ssh/ctrl"
mkdir -p "$SSH_CTRL_DIR"
SSH_CTRL_SOCKET="$SSH_CTRL_DIR/proxmox-ctrl-%r@%h:%p"

SSH_OPTS="-o ControlMaster=auto -o ControlPersist=10m -o ControlPath=$SSH_CTRL_SOCKET"

echo "🔌 Activation du multiplexing SSH..."

############################################
# 1. EXECUTION DU SCRIPT 1 EN LOCAL
############################################
echo "▶️  Exécution du script 1 (génération des clés SSH)..."
bash "$SCRIPT1"

if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo "❌ ERREUR : clé publique introuvable : $SSH_KEY_PATH"
    exit 1
fi

SSH_PUBLIC_KEY_CONTENT="$(cat "$SSH_KEY_PATH")"
echo "✔️  Clé publique récupérée."

############################################
# 2. COPIE DES SCRIPTS SUR PROXMOX
############################################
echo "📁 Création du dossier distant sur Proxmox..."
ssh $SSH_OPTS "${PROXMOX_USER}@${PROXMOX_HOST}" "mkdir -p $REMOTE_DIR"

echo "📤 Envoi des scripts vers Proxmox..."
scp $SSH_OPTS "$SCRIPT2" "${PROXMOX_USER}@${PROXMOX_HOST}:${REMOTE_SCRIPT2}"
scp $SSH_OPTS "$SCRIPT3" "${PROXMOX_USER}@${PROXMOX_HOST}:${REMOTE_SCRIPT3}"
scp $SSH_OPTS "$SCRIPT4" "${PROXMOX_USER}@${PROXMOX_HOST}:${REMOTE_SCRIPT4}"

############################################
# 3. PERMISSIONS
############################################
echo "🔧 Application des permissions..."
ssh $SSH_OPTS "${PROXMOX_USER}@${PROXMOX_HOST}" "chmod +x ${REMOTE_SCRIPT2} ${REMOTE_SCRIPT3} ${REMOTE_SCRIPT4}"

############################################
# 4. EXECUTION DU SCRIPT 2 (création user)
############################################
echo "🚀 Exécution du script 2 sur Proxmox..."
ssh $SSH_OPTS "${PROXMOX_USER}@${PROXMOX_HOST}" \
    "${REMOTE_SCRIPT2} \"${SSH_PUBLIC_KEY_CONTENT}\""

############################################
# 5. EXECUTION DU SCRIPT 3 (téléchargement images cloud)
############################################
echo "☁️  Téléchargement des images Cloud-init sur Proxmox (mode: $SCRIPT3_ARG)..."
ssh $SSH_OPTS "${PROXMOX_USER}@${PROXMOX_HOST}" "${REMOTE_SCRIPT3} ${SCRIPT3_ARG}"

############################################
# 6. EXECUTION DU SCRIPT 4 (création templates)
############################################
echo "📦 Création des templates Proxmox..."
ssh $SSH_OPTS "${PROXMOX_USER}@${PROXMOX_HOST}" "${REMOTE_SCRIPT4}"

echo "🎉 Pipeline IaC terminé avec succès."
