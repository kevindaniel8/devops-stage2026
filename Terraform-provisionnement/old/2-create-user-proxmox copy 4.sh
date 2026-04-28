#!/bin/bash
set -euo pipefail

USER_ID="terraform"
REALM="pve"
ROLE_ID="TerraformRole"
TOKEN_ID="terraform-token"
PERMISSION_PATH="/"
COMMENT="Terraform automation user"

############################################
# 0. PARAMÈTRES & VALEURS PAR DÉFAUT
############################################

SSH_PUBLIC_KEY_CONTENT="${1:-""}"
OUTPUT_FILE="${2:-"/home/kevin-stage-devops/terraform-config.txt"}"

if [[ -z "$SSH_PUBLIC_KEY_CONTENT" ]]; then
    echo -e "\033[1;33m[WARN 0.2]\033[0m Aucune clé SSH fournie — le fichier Terraform contiendra un commentaire."
fi

############################################
# LOGGING
############################################
log() { echo -e "\033[1;32m[INFO $1]\033[0m ${2}"; }
warn() { echo -e "\033[1;33m[WARN $1]\033[0m ${2}"; }
error() { echo -e "\033[1;31m[ERROR $1]\033[0m ${2}"; }

############################################
# 1. DELETE EXISTING RESOURCES
############################################
delete_existing() {
    log "1.1" "Suppression des ressources existantes…"

    pveum user token delete "${USER_ID}@${REALM}" "$TOKEN_ID" 2>/dev/null || true
    pveum acl remove "$PERMISSION_PATH" -user "${USER_ID}@${REALM}" 2>/dev/null || true
    pveum role delete "$ROLE_ID" 2>/dev/null || true
    pveum user delete "${USER_ID}@${REALM}" 2>/dev/null || true

    log "1.2" "Nettoyage terminé."
}

############################################
# 2. CREATE USER + ROLE + PERMISSIONS
############################################
create_user_and_role() {
    log "2.1" "Création de l'utilisateur ${USER_ID}@${REALM}"
    pveum user add "${USER_ID}@${REALM}" --comment "$COMMENT"

    log "2.2" "Création du rôle $ROLE_ID"
    pveum role add "$ROLE_ID" -privs "
        VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU
        VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory
        VM.Config.Network VM.Config.Options VM.Console VM.PowerMgmt
        Datastore.Allocate Datastore.AllocateSpace Datastore.Audit
    "

    log "2.3" "Attribution du rôle à l'utilisateur"
    pveum aclmod "$PERMISSION_PATH" -user "${USER_ID}@${REALM}" -role "$ROLE_ID"
}

############################################
# 3. CREATE TOKEN
############################################
create_token() {
    log "3.1" "Création du token API"

    TOKEN_OUTPUT=$(pveum user token add "${USER_ID}@${REALM}" "$TOKEN_ID" --privsep=0)

    TOKEN_SECRET=$(echo "$TOKEN_OUTPUT" | grep -oE '[a-f0-9-]{36}' | head -1 || true)

    if [[ -z "$TOKEN_SECRET" ]]; then
        warn "3.2" "Impossible d'extraire automatiquement le secret du token"
        TOKEN_SECRET="<SECRET_NON_RECUPERE>"
    fi

    log "3.3" "Token généré"
    echo "$TOKEN_SECRET"
}


############################################
# 4. INSTALL SSH KEY
############################################
install_ssh_key() {
    log "4.1" "Installation de la clé SSH dans /root/.ssh"

    ROOT_SSH_DIR="/root/.ssh"
    ROOT_KEY_PATH="$ROOT_SSH_DIR/id_ed25519_terraform-proxmox.pub"

    mkdir -p "$ROOT_SSH_DIR"
    echo "$SSH_PUBLIC_KEY_CONTENT" > "$ROOT_KEY_PATH"
    chmod 644 "$ROOT_KEY_PATH"

    log "4.2" "Clé SSH installée dans $ROOT_KEY_PATH"

    ############################################
    # 4.3 — COPIE DE SÉCURITÉ DANS /home/kevin-stage-devops/ssh
    ############################################
    BACKUP_USER_DIR="/home/kevin-stage-devops/ssh"
    BACKUP_FILE="$BACKUP_USER_DIR/id_ed25519_terraform-proxmox.pub"

    mkdir -p "$BACKUP_USER_DIR"
    echo "$SSH_PUBLIC_KEY_CONTENT" > "$BACKUP_FILE"
    chmod 644 "$BACKUP_FILE"

    log "4.4" "Copie de la clé publique effectuée dans : $BACKUP_FILE"
}

############################################
# 5. GENERATE TERRAFORM CONFIG FILE
############################################
generate_terraform_config() {
    local token_secret="$1"

    log "5.1" "Génération du fichier Terraform : $OUTPUT_FILE"

    ROOT_KEY_PATH="/root/.ssh/id_ed25519_terraform-proxmox.pub"

    if [[ -f "$ROOT_KEY_PATH" ]]; then
        SSH_KEY_FOR_TF="$(cat "$ROOT_KEY_PATH")"
    else
        SSH_KEY_FOR_TF="# clé ssh à remplacer si besoin"
        warn "5.1" "Clé SSH introuvable dans $ROOT_KEY_PATH — ajout d'un commentaire dans le fichier Terraform."
    fi

    cat > "$OUTPUT_FILE" << EOF
pm_host         = "192.168.0.1"
pm_token_id     = "${USER_ID}@${REALM}!${TOKEN_ID}"
pm_token_secret = "$token_secret"
proxmox_node    = "pve"
template_id     = 800
disk_storage    = "local-lvm"
net_bridge      = "vmbr1"

ssh_user        = "ubuntu"
vm_password     = "ubuntu"
ssh_public_key  = "$SSH_KEY_FOR_TF"
mode            = "dev"

vmid_start      = 500
gateway         = "192.168.20.1"
dns_server      = "8.8.8.8"
EOF

    chmod 600 "$OUTPUT_FILE"
    log "5.2" "Fichier Terraform généré."
}

############################################
# 6. MAIN EXECUTION
############################################
main() {
    log "0" "Démarrage du script Proxmox Terraform Setup"

    delete_existing
    create_user_and_role
    TOKEN_SECRET=$(create_token)
    install_ssh_key
    generate_terraform_config "$TOKEN_SECRET"

    log "6.1" "Configuration terminée."
    log "6.2" "Token secret : $TOKEN_SECRET"
}

main
