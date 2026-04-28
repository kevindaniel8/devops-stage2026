#!/bin/bash
set -euo pipefail

USER_ID="terraform"
REALM="pve"
ROLE_ID="TerraformRole"
TOKEN_ID="terraform-token"
PERMISSION_PATH="/"
COMMENT="Terraform automation user"

SSH_PUBLIC_KEY_CONTENT="$1"
OUTPUT_FILE="$2"

############################################
# LOGGING
############################################
log() { echo -e "\033[1;32m[INFO]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

############################################
# DELETE EXISTING RESOURCES
############################################
delete_existing() {
    log "Suppression des ressources existantes…"

    pveum user token delete "${USER_ID}@${REALM}" "$TOKEN_ID" 2>/dev/null || true
    pveum acl remove "$PERMISSION_PATH" -user "${USER_ID}@${REALM}" 2>/dev/null || true
    pveum role delete "$ROLE_ID" 2>/dev/null || true
    pveum user delete "${USER_ID}@${REALM}" 2>/dev/null || true

    log "Nettoyage terminé."
}

############################################
# CREATE USER + ROLE + PERMISSIONS
############################################
create_user_and_role() {
    log "Création de l'utilisateur ${USER_ID}@${REALM}"
    pveum user add "${USER_ID}@${REALM}" --comment "$COMMENT"

    log "Création du rôle $ROLE_ID"
    pveum role add "$ROLE_ID" -privs "
        VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU
        VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory
        VM.Config.Network VM.Config.Options VM.Console VM.PowerMgmt
        Datastore.Allocate Datastore.AllocateSpace Datastore.Audit
    "

    log "Attribution du rôle à l'utilisateur"
    pveum aclmod "$PERMISSION_PATH" -user "${USER_ID}@${REALM}" -role "$ROLE_ID"
}

############################################
# CREATE TOKEN
############################################
create_token() {
    log "Création du token API"

    TOKEN_OUTPUT=$(pveum user token add "${USER_ID}@${REALM}" "$TOKEN_ID" --privsep=0)

    TOKEN_SECRET=$(echo "$TOKEN_OUTPUT" | grep -oE '[a-f0-9-]{36}' | head -1 || true)

    if [[ -z "$TOKEN_SECRET" ]]; then
        warn "Impossible d'extraire automatiquement le secret du token"
        TOKEN_SECRET="<SECRET_NON_RECUPERE>"
    fi

    echo "$TOKEN_SECRET"
}

############################################
# INSTALL SSH KEY
############################################
install_ssh_key() {
    log "Installation de la clé SSH dans /root/.ssh"

    mkdir -p /root/.ssh
    echo "$SSH_PUBLIC_KEY_CONTENT" > /root/.ssh/id_ed25519_terraform-proxmox.pub
    chmod 644 /root/.ssh/id_ed25519_terraform-proxmox.pub

    log "Clé SSH installée."
}

############################################
# GENERATE TERRAFORM CONFIG FILE
############################################
generate_terraform_config() {
    local token_secret="$1"

    log "Génération du fichier Terraform : $OUTPUT_FILE"

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
ssh_public_key  = "$SSH_PUBLIC_KEY_CONTENT"
mode            = "dev"

vmid_start      = 500
gateway         = "192.168.20.1"
dns_server      = "8.8.8.8"
EOF

    chmod 600 "$OUTPUT_FILE"
    log "Fichier Terraform généré."
}

############################################
# MAIN EXECUTION
############################################
main() {
    delete_existing
    create_user_and_role
    TOKEN_SECRET=$(create_token)
    install_ssh_key
    generate_terraform_config "$TOKEN_SECRET"

    log "Configuration terminée."
    log "Token secret : $TOKEN_SECRET"
}

main
