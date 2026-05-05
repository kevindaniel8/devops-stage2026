#!/bin/bash
# =============================================================================
# Script: 5-generate-terraform-config.sh
# Description: Génère le fichier terraform.tfvars basé sur les credentials créés
# =============================================================================

set -e

# Charger les variables d'environnement globales
ENV_FILE="${ENV_FILE:-./env.conf}"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    echo "✅ Configuration chargée depuis: $ENV_FILE"
else
    echo "⚠️  Fichier env.conf non trouvé, utilisation des valeurs par défaut"
fi

# Couleurs
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}  Génération Config Terraform${NC}"
echo -e "${BLUE}===============================================${NC}"
echo ""

# Configuration Proxmox (utilise env.conf ou valeurs par défaut)
PM_HOST="${PM_HOST:-192.168.0.1}"
PROXMOX_NODE="${PM_NODE:-pve}"
SSH_USER="${VM_SSH_USER:-terraform}"

# Template à utiliser (9001=Debian, 9002=Ubuntu24, 9003=Ubuntu26)
TEMPLATE_ID="${TEMPLATE_ID:-9001}"

# Configuration réseau depuis env.conf
NET_BRIDGE="${NET_BRIDGE:-vmbr1}"
GATEWAY="${GATEWAY:-192.168.20.1}"
DNS_SERVER="${DNS_SERVER:-8.8.8.8}"

# Récupérer le token depuis le serveur Proxmox
echo -e "${YELLOW}[INFO]${NC} Récupération du token API depuis Proxmox..."

# Récupérer l'ID du token (|| true pour éviter que set -e arrête le script)
REMOTE_DIR="${REMOTE_DIR:-/home/kevin-stage-devops}"
PM_TOKEN_ID=$(ssh root@$PM_HOST "grep -o 'terraform[^!]*![^\"]*' $REMOTE_DIR/terraform-config.txt 2>/dev/null | head -1" 2>/dev/null || echo '') || true

if [ -z "$PM_TOKEN_ID" ]; then
    PM_TOKEN_ID="terraform-token@pve!token"
    echo -e "${YELLOW}[WARN]${NC} Token ID non trouvé, utilisation valeur par défaut: $PM_TOKEN_ID"
else
    echo -e "${GREEN}[OK]${NC} Token ID trouvé: $PM_TOKEN_ID"
fi

# Récupérer le secret du token depuis terraform-config.txt
# Format attendu: pm_token_secret = " valeur " ou pm_token_secret = "valeur" sur une ligne
PM_TOKEN_SECRET=$(ssh root@$PM_HOST "grep 'pm_token_secret' $REMOTE_DIR/terraform-config.txt 2>/dev/null | cut -d'=' -f2- | tr -d ' \"'" 2>/dev/null || echo '') || true
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

# Lecture des définitions de VMs depuis fichier JSON
VM_CONFIG_FILE="${VM_CONFIG_FILE:-./vm-definitions.json}"

if [ -f "$VM_CONFIG_FILE" ]; then
    echo -e "${GREEN}[OK]${NC} Fichier de configuration VMs trouvé: $VM_CONFIG_FILE"
    
    # Extraire les valeurs du JSON (nécessite jq)
    if command -v jq &> /dev/null; then
        VMID_START=$(jq -r '.vmid_start // 200' "$VM_CONFIG_FILE")
        GATEWAY=$(jq -r '.network.gateway // "192.168.20.1"' "$VM_CONFIG_FILE")
        DNS_SERVER=$(jq -r '.network.dns_server // "8.8.8.8"' "$VM_CONFIG_FILE")
        SUBNET=$(jq -r '.network.subnet // "192.168.20"' "$VM_CONFIG_FILE")
    else
        echo -e "${YELLOW}[WARN]${NC} jq non installé - utilisation des valeurs par défaut"
        VMID_START=200
        GATEWAY="192.168.20.1"
        DNS_SERVER="8.8.8.8"
        SUBNET="192.168.20"
    fi
else
    echo -e "${YELLOW}[WARN]${NC} Fichier $VM_CONFIG_FILE non trouvé - utilisation des valeurs par défaut"
    VMID_START=200
    GATEWAY="192.168.20.1"
    DNS_SERVER="8.8.8.8"
    SUBNET="192.168.20"
fi

# Générer le fichier terraform.tfvars
TFVARS_FILE="./Terraform/terraform.tfvars"

# Supprimer l'ancien fichier pour forcer la régénération (idempotent)
if [ -f "$TFVARS_FILE" ]; then
    echo -e "${YELLOW}[INFO]${NC} Suppression de l'ancien $TFVARS_FILE..."
    rm -f "$TFVARS_FILE"
fi

echo -e "${YELLOW}[INFO]${NC} Génération de $TFVARS_FILE..."

# Générer l'en-tête du fichier
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
disk_storage = "${DISK_STORAGE:-local-lvm}"
net_bridge   = "$NET_BRIDGE"

# --- Authentification VMs ---
ssh_user       = "$SSH_USER"
vm_password    = "${VM_PASSWORD:-changeme}"  # utilisé uniquement en mode DEV - CHANGER CETTE VALEUR!
ssh_public_key = "$SSH_PUBLIC_KEY"
mode           = "${MODE:-dev}"  # dev = mot de passe + clé SSH / prod = clé SSH uniquement

# --- Plage VMID ---
vmid_start = $VMID_START

# --- Définition des VMs ---
# Chargé depuis: $VM_CONFIG_FILE
# Modifiez ce fichier pour ajouter/supprimer des VMs
vm_definitions = {
EOF

# Générer les définitions de VMs depuis le JSON
if [ -f "$VM_CONFIG_FILE" ] && command -v jq &> /dev/null; then
    # Compter le nombre de VMs (|| true pour éviter erreur set -e)
    VM_COUNT=$(jq '.vms | length' "$VM_CONFIG_FILE") || true
    VM_COUNT="${VM_COUNT:-0}"
    
    for i in $(seq 0 $((VM_COUNT - 1))); do
        VM_NAME=$(jq -r ".vms[$i].name" "$VM_CONFIG_FILE")
        IP_SUFFIX=$(jq -r ".vms[$i].ip_suffix" "$VM_CONFIG_FILE")
        CORES=$(jq -r ".vms[$i].cores" "$VM_CONFIG_FILE")
        MEMORY=$(jq -r ".vms[$i].memory" "$VM_CONFIG_FILE")
        DISK=$(jq -r ".vms[$i].disk" "$VM_CONFIG_FILE")
        DESC=$(jq -r ".vms[$i].description" "$VM_CONFIG_FILE")
        
        # Calculer l'IP complète
        IP="${SUBNET}.${IP_SUFFIX}"
        
        # Ajouter une virgule après chaque VM sauf la dernière
        if [ $i -lt $((VM_COUNT - 1)) ]; then
            COMMA=","
        else
            COMMA=""
        fi
        
        cat >> "$TFVARS_FILE" << EOF
  # $DESC
  $VM_NAME = {
    ip     = "$IP"
    cores  = $CORES
    memory = $MEMORY
    disk   = $DISK
  }$COMMA
EOF
    done
else
    # Valeurs par défaut si pas de JSON
    cat >> "$TFVARS_FILE" << EOF
  # VM de test (défaut)
  test-vm = {
    ip     = "${SUBNET}.200"
    cores  = 2
    memory = 2048
    disk   = 20
  },
  
  # VM applicative (défaut)
  app-server = {
    ip     = "${SUBNET}.201"
    cores  = 2
    memory = 4096
    disk   = 40
  }
EOF
fi

# Fermer le bloc vm_definitions
cat >> "$TFVARS_FILE" << EOF
}

# --- Réseau ---
gateway    = "${GATEWAY:-192.168.20.1}"
dns_server = "${DNS_SERVER:-8.8.8.8}"

# --- Optimisations Cloud-init ---
# Mode rapide: VM créée sans démarrage automatique (~30s par VM)
# Mode complet: VM démarrée avec attente agent QEMU (~2-3 min par VM)
wait_for_cloudinit = false

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
echo "  Proxmox Host:   $PM_HOST"
echo "  Proxmox Node:   $PROXMOX_NODE"
echo "  Template ID:    $TEMPLATE_ID"
echo "  SSH User:       $SSH_USER"
echo "  VMID Start:     $VMID_START"
echo "  Gateway:        $GATEWAY"
echo "  Config VMs:     $VM_CONFIG_FILE"
if [ -f "$VM_CONFIG_FILE" ] && command -v jq &> /dev/null; then
    VM_COUNT=$(jq '.vms | length' "$VM_CONFIG_FILE")
    echo "  VMs définies:   $VM_COUNT"
fi
echo ""
echo -e "${YELLOW}Prochaines étapes:${NC}"
echo "  1. Configurer les VMs: nano $VM_CONFIG_FILE"
echo "  2. Modifier le mot de passe: nano $TFVARS_FILE (vm_password)"
echo "  3. Regénérer la config: ./5-generate-terraform-config.sh"
echo "  4. cd ./Terraform"
echo "  5. terraform plan"
echo "  6. terraform apply"
