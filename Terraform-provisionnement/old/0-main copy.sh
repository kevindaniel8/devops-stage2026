#!/bin/bash
set -euo pipefail

############################################
# CONFIG
############################################
PROXMOX_HOST="192.168.0.1"
PROXMOX_USER="root"
PROXMOX_SCRIPT_PATH="/home/kevin-stage-devops/2-create-user-proxmox.sh"

SCRIPT1="./1-generate-ssh-keys.sh"
SCRIPT2="./2-create-user-proxmox.sh"

SSH_KEY_PATH="./ssh/id_ed25519_terraform-proxmox.pub"

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
# 2. COPIE DU SCRIPT 2 SUR PROXMOX
############################################
echo "📤 Envoi du script 2 vers Proxmox..."
scp "$SCRIPT2" "${PROXMOX_USER}@${PROXMOX_HOST}:${PROXMOX_SCRIPT_PATH}"

############################################
# 3. RENDRE LE SCRIPT EXECUTABLE
############################################
echo "🔧 Application des permissions sur Proxmox..."
ssh "${PROXMOX_USER}@${PROXMOX_HOST}" "chmod +x ${PROXMOX_SCRIPT_PATH}"

############################################
# 4. EXECUTION DU SCRIPT 2 A DISTANCE
############################################
echo "🚀 Exécution du script 2 sur Proxmox..."
ssh "${PROXMOX_USER}@${PROXMOX_HOST}" \
    "${PROXMOX_SCRIPT_PATH} \"${SSH_PUBLIC_KEY_CONTENT}\""

echo "🎉 Pipeline IaC terminé avec succès."
