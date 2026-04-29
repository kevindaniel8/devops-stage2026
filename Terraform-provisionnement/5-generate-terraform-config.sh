#!/bin/bash
# =============================================================================
# Script: 5-generate-terraform-config.sh
# Description: Génère le fichier terraform.tfvars basé sur les credentials créés
# =============================================================================

set -e

# Couleurs
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}  Génération Config Terraform${NC}"
echo -e "${BLUE}===============================================${NC}"
echo ""

# Configuration Proxmox
PM_HOST="${PM_HOST:-192.168.0.1}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
SSH_USER="${SSH_USER:-terraform}"

# Template à utiliser (9001=Debian, 9002=Ubuntu24, 9003=Ubuntu26)
TEMPLATE_ID="${TEMPLATE_ID:-9001}"

# Récupérer le token depuis le serveur Proxmox
echo -e "${YELLOW}[INFO]${NC} Récupération du token API depuis Proxmox..."

# Récupérer l'ID du token
PM_TOKEN_ID=$(ssh root@$PM_HOST "grep -o 'terraform[^!]*![^\"]*' /home/kevin-stage-devops/terraform-config.txt 2>/dev/null | head -1" 2>/dev/null || echo '')

if [ -z "$PM_TOKEN_ID" ]; then
    PM_TOKEN_ID="terraform-token@pve!token"
    echo -e "${YELLOW}[WARN]${NC} Token ID non trouvé, utilisation valeur par défaut: $PM_TOKEN_ID"
else
    echo -e "${GREEN}[OK]${NC} Token ID trouvé: $PM_TOKEN_ID"
fi

# Récupérer le secret du token depuis terraform-config.txt
# Format attendu: pm_token_secret = " valeur " ou pm_token_secret = "valeur" sur une ligne
PM_TOKEN_SECRET=$(ssh root@$PM_HOST "grep 'pm_token_secret' /home/kevin-stage-devops/terraform-config.txt 2>/dev/null | cut -d'=' -f2- | tr -d ' \"'" 2>/dev/null || echo '')
#PM_TOKEN_SECRET=$(ssh root@$PM_HOST "cat /home/kevin-stage-devops/terraform-config.txt | tr ' ' '\n' | grep -A1 'pm_token_secret' | tail -1 | tr -d '\\\"'" 2>/dev/null || echo '')

if [ -z "$PM_TOKEN_SECRET" ]; then
    echo ""
    echo -e "${YELLOW}[WARN]${NC} Token secret non trouvé dans terraform-config.txt"
    echo "      Utilisation d'une valeur placeholder"
    PM_TOKEN_SECRET="CHANGEME_VOTRE_TOKEN_SECRET"
else
    echo -e "${GREEN}[OK]${NC} Token secret récupéré depuis terraform-config.txt"
fi

# Récupérer la clé SSH publique
SSH_KEY_FILE="${HOME}/.ssh/id_ed25519_terraform-proxmox.pub"
if [ -f "$SSH_KEY_FILE" ]; then
    SSH_PUBLIC_KEY=$(cat "$SSH_KEY_FILE")
else
    echo -e "${YELLOW}[WARN]${NC} Clé SSH non trouvée: $SSH_KEY_FILE"
    SSH_PUBLIC_KEY="CHANGEME_VOTRE_CLE_SSH"
fi

# Générer le fichier terraform.tfvars
TFVARS_FILE="/home/kevin/devops-stage2026/Terraform-provisionnement/Terraform/terraform.tfvars"

echo -e "${YELLOW}[INFO]${NC} Génération de $TFVARS_FILE..."

cat > "$TFVARS_FILE" << EOF
# ============================================
# Configuration Proxmox - Générée automatiquement
# Date: $(date '+%Y-%m-%d %H:%M:%S')
# ============================================

# --- Connexion Proxmox ---
pm_host         = "$PM_HOST"
pm_token_id     = "$PM_TOKEN_ID"
pm_token_secret = "$PM_TOKEN_SECRET"

# --- Paramètres VMs ---
proxmox_node = "$PROXMOX_NODE"
template_id  = $TEMPLATE_ID
disk_storage = "local-lvm"
net_bridge   = "vmbr1"

# --- Authentification VMs ---
ssh_user       = "$SSH_USER"
vm_password    = "changeme"  # utilisé uniquement en mode DEV - CHANGER CETTE VALEUR!
ssh_public_key = "$SSH_PUBLIC_KEY"
mode           = "dev"  # dev = mot de passe + clé SSH / prod = clé SSH uniquement

# --- Plage VMID ---
vmid_start = 200

# --- Définition des VMs (exemple) ---
# Ajoutez vos VMs ici ou modifiez selon vos besoins
vm_definitions = {
  # Exemple: VM de test (IP de départ: 192.168.20.200)
  test-vm = {
    ip     = "192.168.20.200"
    cores  = 2
    memory = 2048
    disk   = 20
  }
  
  # Exemple: VM applicative
  app-server = {
    ip     = "192.168.20.201"
    cores  = 2
    memory = 4096
    disk   = 40
  }
}

# --- Réseau ---
gateway    = "192.168.20.1"
dns_server = "8.8.8.8"

# ============================================
# Notes:
# - Template utilisé: $TEMPLATE_ID
#   (9001=Debian13, 9002=Ubuntu24.04, 9003=Ubuntu26.04)
# - Modifiez vm_definitions pour ajouter vos VMs
# - En mode 'prod', retirez vm_password
# ============================================
EOF

    echo -e "${YELLOW}[WARN]${NC} Remplacez CHANGEME_VOTRE_TOKEN_SECRET par le vrai token"
    echo "      Récupérez-le depuis Proxmox: Datacenter → Permissions → API Tokens"
    echo ""
    echo -e "${GREEN}[OK]${NC} Fichier généré: $TFVARS_FILE"
echo ""
echo -e "${BLUE}--- Récapitulatif ---${NC}"
echo "  Proxmox Host: $PM_HOST"
echo "  Proxmox Node: $PROXMOX_NODE"
echo "  Template ID:  $TEMPLATE_ID"
echo "  SSH User:     $SSH_USER"
echo ""
echo -e "${YELLOW}Prochaines étapes:${NC}"
echo "  1. Modifier le fichier: nano $TFVARS_FILE"
echo "  2. Personnaliser vm_definitions avec vos VMs"
echo "  3. Changer le mot de passe vm_password"
echo "  4. cd /home/kevin/devops-stage2026/Terraform-provisionnement/Terraform"
echo "  5. terraform init (si pas déjà fait)"
echo "  6. terraform plan"
echo "  7. terraform apply"
