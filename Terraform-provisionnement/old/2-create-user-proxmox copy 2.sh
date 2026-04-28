#!/bin/bash
set -e

USER_ID="terraform"
REALM="pve"
ROLE_ID="TerraformRole"
TOKEN_ID="terraform-token"
PERMISSION_PATH="/"
COMMENT="Terraform automation user"
SSH_DIR="/home/kevin-stage/ssh"
SSH_KEY_FILE="$SSH_DIR/id_ed25519_terraform-proxmox.pub"

echo "=== Vérification de la clé SSH ==="
if [ ! -f "$SSH_KEY_FILE" ]; then
    echo "⚠️  Clé SSH non trouvée dans $SSH_KEY_FILE"
    echo "Création d'un fichier placeholder..."
    mkdir -p "$SSH_DIR"
    echo "# Clé publique SSH à remplacer" > "$SSH_KEY_FILE"
fi
echo "✅ Clé SSH présente dans $SSH_DIR/"

echo "=== Nettoyage des ressources existantes ==="

# Supprimer le fichier de configuration s'il existe
TERRAFORM_FILE="/home/kevin-stage/terraform-config.txt"
if [ -f "$TERRAFORM_FILE" ]; then
    echo "Suppression du fichier de configuration existant: $TERRAFORM_FILE"
    rm -f "$TERRAFORM_FILE"
fi

# Supprimer le token s'il existe
if pveum user token list "${USER_ID}@${REALM}" 2>/dev/null | grep -q "$TOKEN_ID"; then
    echo "Suppression du token existant: $TOKEN_ID"
    pveum user token delete "${USER_ID}@${REALM}" "$TOKEN_ID" 2>/dev/null || true
fi

# Supprimer les permissions ACL si elles existent
if pveum acl list 2>/dev/null | grep -q "${USER_ID}@${REALM}"; then
    echo "Suppression des permissions ACL existantes"
    pveum acl remove "$PERMISSION_PATH" -user "${USER_ID}@${REALM}" 2>/dev/null || true
fi

# Supprimer le rôle s'il existe
if pveum role list 2>/dev/null | grep -q "$ROLE_ID"; then
    echo "Suppression du rôle existant: $ROLE_ID"
    pveum role delete "$ROLE_ID" 2>/dev/null || true
fi

# Supprimer l'utilisateur s'il existe
if pveum user list 2>/dev/null | grep -q "${USER_ID}@${REALM}"; then
    echo "Suppression de l'utilisateur existant: ${USER_ID}@${REALM}"
    pveum user delete "${USER_ID}@${REALM}" 2>/dev/null || true
fi

echo "=== Nettoyage terminé ==="

echo "=== Création de l'utilisateur Proxmox ==="
pveum user add "${USER_ID}@${REALM}" --comment "$COMMENT"

echo "=== Création du rôle TerraformRole ==="
pveum role add "$ROLE_ID" -privs "VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Console VM.PowerMgmt Datastore.Allocate Datastore.AllocateSpace Datastore.Audit"

echo "=== Attribution du rôle à l'utilisateur ==="
pveum aclmod "$PERMISSION_PATH" -user "${USER_ID}@${REALM}" -role "$ROLE_ID"

echo "=== Vérification des permissions ==="
pveum acl list | grep "${USER_ID}@${REALM}"

echo "=== Création du token API ==="
TOKEN_OUTPUT=$(pveum user token add "${USER_ID}@${REALM}" "$TOKEN_ID" --privsep=0)

# Extraire le secret du token
TOKEN_SECRET=$(echo "$TOKEN_OUTPUT" | grep -oE 'key: [a-f0-9-]+' | cut -d' ' -f2)
if [ -z "$TOKEN_SECRET" ]; then
    TOKEN_SECRET=$(echo "$TOKEN_OUTPUT" | grep -oE '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' | head -1)
fi
if [ -z "$TOKEN_SECRET" ]; then
    TOKEN_SECRET=$(echo "$TOKEN_OUTPUT" | grep -oE '"value":"[^"]+"' | cut -d'"' -f4)
fi
if [ -z "$TOKEN_SECRET" ]; then
    TOKEN_SECRET="<SECRET_NON_RECUPERE>"
    echo "AVERTISSEMENT: Impossible de récupérer le secret du token automatiquement"
fi

echo "=== Liste des tokens de l'utilisateur ==="
pveum user token list "${USER_ID}@${REALM}"

# Pause de 1 seconde avant de créer le fichier de configuration
echo "⏱️  Pause de 1 seconde..."
sleep 1

# Lire la clé SSH publique depuis kevin-stage/ssh/
SSH_KEY_FILE="/home/kevin-stage/ssh/id_ed25519_terraform-proxmox.pub"
echo "📋 Lecture de la clé SSH publique depuis $SSH_KEY_FILE..."

if [ -f "$SSH_KEY_FILE" ]; then
    SSH_PUBLIC_KEY_CONTENT=$(cat "$SSH_KEY_FILE")
    echo "✅ Clé SSH publique lue avec succès"
    
    # Créer le dossier de backup s'il n'existe pas
    BACKUP_DIR="/root/.ssh/backup"
    mkdir -p "$BACKUP_DIR"
    
    # Sauvegarder l'ancienne clé si elle existe
    if [ -f /root/.ssh/id_ed25519_terraform-proxmox.pub ]; then
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        echo "📦 Sauvegarde de l'ancienne clé SSH dans $BACKUP_DIR/"
        cp /root/.ssh/id_ed25519_terraform-proxmox.pub "$BACKUP_DIR/id_ed25519_terraform-proxmox.pub.$TIMESTAMP"
        echo "✅ Ancienne clé sauvegardée: id_ed25519_terraform-proxmox.pub.$TIMESTAMP"
    fi
    
    # Copier la clé SSH dans le dossier .ssh de Proxmox
    echo "📁 Copie de la clé SSH dans ~/.ssh de Proxmox..."
    cp "$SSH_KEY_FILE" /root/.ssh/id_ed25519_terraform-proxmox.pub
    chmod 644 /root/.ssh/id_ed25519_terraform-proxmox.pub
    echo "✅ Clé SSH copiée dans ~/.ssh"
else
    echo "⚠️  Clé SSH non trouvée, utilisation d'un placeholder"
    SSH_PUBLIC_KEY_CONTENT="VOTRE_CLÉ_PUBLIQUE_ICI"
fi

echo "=== Création du fichier de configuration Terraform ==="
TERRAFORM_FILE="/home/kevin-stage/terraform-config.txt"
cat > "$TERRAFORM_FILE" << EOF
# Configuration Terraform pour Proxmox
# Généré automatiquement le $(date)

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

chmod 600 "$TERRAFORM_FILE"
echo "Fichier de configuration créé: $TERRAFORM_FILE"
echo "Permissions sécurisées (600) appliquées"

echo "=== Infos à utiliser dans Terraform ==="
echo "pm_user        = \"${USER_ID}@${REALM}\""
echo "pm_token_name  = \"${TOKEN_ID}\""
echo "pm_token_id    = \"${USER_ID}@${REALM}!${TOKEN_ID}\""
echo "pm_token_secret = \"$TOKEN_SECRET\""
echo ""
echo "🔐 Le secret du token est sauvegardé dans: $TERRAFORM_FILE"
echo ""
echo "🎉 Configuration terminée !"
echo "Utilisateur terraform créé avec:"
echo "- Clé SSH intégrée pour GitHub/Terraform"
echo "- Token API généré"
echo "- Droits VM et Datastore attribués"
