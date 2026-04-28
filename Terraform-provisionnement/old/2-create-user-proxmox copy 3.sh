#!/bin/bash
set -e

USER_ID="terraform"
REALM="pve"
ROLE_ID="TerraformRole"
TOKEN_ID="terraform-token"
PERMISSION_PATH="/"
COMMENT="Terraform automation user"

SSH_PUBLIC_KEY_CONTENT="$1"   # clé passée en argument
OUTPUT_FILE="$2"              # fichier de sortie pour Terraform

echo "=== Nettoyage des ressources existantes ==="

pveum user token delete "${USER_ID}@${REALM}" "$TOKEN_ID" 2>/dev/null || true
pveum acl remove "$PERMISSION_PATH" -user "${USER_ID}@${REALM}" 2>/dev/null || true
pveum role delete "$ROLE_ID" 2>/dev/null || true
pveum user delete "${USER_ID}@${REALM}" 2>/dev/null || true

echo "=== Création utilisateur ==="
pveum user add "${USER_ID}@${REALM}" --comment "$COMMENT"

echo "=== Création rôle ==="
pveum role add "$ROLE_ID" -privs "VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Console VM.PowerMgmt Datastore.Allocate Datastore.AllocateSpace Datastore.Audit"

echo "=== Attribution rôle ==="
pveum aclmod "$PERMISSION_PATH" -user "${USER_ID}@${REALM}" -role "$ROLE_ID"

echo "=== Création token ==="
TOKEN_OUTPUT=$(pveum user token add "${USER_ID}@${REALM}" "$TOKEN_ID" --privsep=0)

TOKEN_SECRET=$(echo "$TOKEN_OUTPUT" | grep -oE '[a-f0-9-]{36}' | head -1)
if [ -z "$TOKEN_SECRET" ]; then
    TOKEN_SECRET="<SECRET_NON_RECUPERE>"
fi

echo "=== Installation clé SSH ==="
mkdir -p /root/.ssh
echo "$SSH_PUBLIC_KEY_CONTENT" > /root/.ssh/id_ed25519_terraform-proxmox.pub
chmod 644 /root/.ssh/id_ed25519_terraform-proxmox.pub

echo "=== Génération fichier Terraform ==="
cat > "$OUTPUT_FILE" << EOF
pm_host         = "192.168.0.1"
pm_token_id     = "${USER_ID}@${REALM}!${TOKEN_ID}"
pm_token_secret = "$TOKEN_SECRET"
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

echo "=== Terminé ==="
echo "Token secret : $TOKEN_SECRET"
