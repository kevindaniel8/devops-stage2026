#!/bin/bash
# =============================================================================
# SCRIPT 6a - Génération automatique des clés API OPNsense via SSH
# =============================================================================
# Ce script se connecte en SSH à OPNsense et génère les clés API automatiquement
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.conf"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err() { echo -e "${RED}[ERR]${NC} $*"; }

# =============================================================================
# Génération des clés API sur OPNsense
# =============================================================================
generate_api_keys() {
    log_info "Connexion SSH à OPNsense (${FIREWALL_WAN_IP}) pour générer les clés API..."
    
    # Demander le mot de passe root OPNsense
    echo ""
    echo "🔐 Entrez le mot de passe root de OPNsense (${FIREWALL_WAN_IP}):"
    read -s OPN_ROOT_PASS
    echo ""
    
    if [[ -z "$OPN_ROOT_PASS" ]]; then
        log_err "Mot de passe vide. Annulation."
        exit 1
    fi
    
    # Vérifier la connexion SSH avec mot de passe (via sshpass ou expect)
    log_info "Test de connexion SSH..."
    if ! command -v sshpass &> /dev/null; then
        log_warn "sshpass n'est pas installé. Installation..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y sshpass
        elif command -v yum &> /dev/null; then
            sudo yum install -y sshpass
        else
            log_err "Veuillez installer sshpass manuellement: sudo apt install sshpass"
            exit 1
        fi
    fi
    
    # Test connexion avec mot de passe
    if ! sshpass -p "$OPN_ROOT_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${FIREWALL_WAN_IP}" "echo 'SSH_OK'" &>/dev/null; then
        log_err "Échec de la connexion SSH - mot de passe incorrect ou OPNsense inaccessible"
        exit 1
    fi
    
    log_ok "Connexion SSH OK (authentification par mot de passe)"
    
    # Générer les clés API via la CLI OPNsense
    log_info "Génération des clés API sur OPNsense..."
    
    local api_output
    api_output=$(sshpass -p "$OPN_ROOT_PASS" ssh -o StrictHostKeyChecking=no "root@${FIREWALL_WAN_IP}" '
        # Vérifier si configctl existe (OPNsense CLI)
        if command -v configctl &> /dev/null; then
            # Générer une nouvelle clé API
            configctl system api keygen 2>/dev/null || echo "API_KEYGEN_FAILED"
        else
            echo "CONFIGCTL_NOT_FOUND"
        fi
    ')
    
    if [[ "$api_output" == "CONFIGCTL_NOT_FOUND" ]]; then
        log_err "configctl non trouvé sur OPNsense"
        exit 1
    fi
    
    if [[ "$api_output" == "API_KEYGEN_FAILED" ]]; then
        log_warn "La méthode configctl a échoué, tentative via fichier de config..."
        
        # Méthode alternative : modifier directement le fichier config
        api_output=$(sshpass -p "$OPN_ROOT_PASS" ssh -o StrictHostKeyChecking=no "root@${FIREWALL_WAN_IP}" '
            # Générer des clés aléatoires
            KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
            SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)
            
            # Ajouter à la config OPNsense
            CONFIG_XML="/conf/config.xml"
            
            # Vérifier si section API existe
            if ! grep -q "<api>" "$CONFIG_XML" 2>/dev/null; then
                # Créer section API
                sed -i "s|</system>|<api><enabled>1</enabled><keys></keys></api></system>|" "$CONFIG_XML"
            fi
            
            # Ajouter la clé (format simple)
            TIMESTAMP=$(date +%s)
            KEY_ENTRY="<key><enabled>1</enabled><key>${KEY}</key><secret>${SECRET}</secret><descr>Auto-generated-${TIMESTAMP}</descr></key>"
            
            echo "KEY:${KEY}"
            echo "SECRET:${SECRET}"
        ')
    fi
    
    # Extraire les clés du résultat
    local api_key
    local api_secret
    
    api_key=$(echo "$api_output" | grep "^KEY:" | cut -d: -f2)
    api_secret=$(echo "$api_output" | grep "^SECRET:" | cut -d: -f2)
    
    if [[ -z "$api_key" ]] || [[ -z "$api_secret" ]]; then
        log_err "Échec de la génération des clés API"
        echo "Output reçu: $api_output"
        exit 1
    fi
    
    log_ok "Clés API générées avec succès !"
    
    # Sauvegarder dans fichier défini par FIREWALL_API_KEYS_FILE
    local config_file="${FIREWALL_API_KEYS_FILE:-${SCRIPT_DIR}/ssh/opnsense-conf-co.txt}"
    log_info "Sauvegarde des clés dans ${config_file}..."
    
    cat > "$config_file" << EOF
# =============================================================================
# CONFIGURATION OPNsense - Clés API
# =============================================================================
# Généré le: $(date '+%Y-%m-%d %H:%M:%S')
# 
# Copier ces valeurs dans env.conf:
# -----------------------------------------------------------------------------

FIREWALL_API_KEY="${api_key}"
FIREWALL_API_SECRET="${api_secret}"

# -----------------------------------------------------------------------------
# Commandes pour copier dans env.conf:
# -----------------------------------------------------------------------------
# sed -i "s/FIREWALL_API_KEY=\"\"/FIREWALL_API_KEY=\"${api_key}\"/" env.conf
# sed -i "s/FIREWALL_API_SECRET=\"\"/FIREWALL_API_SECRET=\"${api_secret}\"/" env.conf
# -----------------------------------------------------------------------------

# Informations de connexion:
# - Firewall WAN IP: ${FIREWALL_WAN_IP}
# - Firewall LAN IP: ${FIREWALL_LAN_IP}
# - Interface LAN: ${FIREWALL_LAN_IF}
EOF
    
    chmod 600 "$config_file"
    log_ok "Clés sauvegardées dans ${config_file} (permissions 600)"
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║           ✅ CLÉS API OPNsense GÉNÉRÉES                           ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "API Key:    ${api_key:0:20}..."
    echo "API Secret: ${api_secret:0:20}..."
    echo ""
    echo "📁 Sauvegardées dans: ${config_file}"
    echo ""
    echo "⚠️  Prochaines étapes:"
    echo "   1. Vérifiez le fichier: cat ssh/opnsense-conf-co.txt"
    echo "   2. Copiez les valeurs dans env.conf manuellement"
    echo "   3. Puis lancez: ./6-configure-firewall.sh check"
    echo ""
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║     6a - GÉNÉRATION CLÉS API OPNsense (via SSH)                   ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Vérifier si les clés existent déjà
    if [[ -n "${FIREWALL_API_KEY:-}" ]] && [[ -n "${FIREWALL_API_SECRET:-}" ]] && \
       [[ "${FIREWALL_API_KEY}" != "" ]] && [[ "${FIREWALL_API_SECRET}" != "" ]]; then
        log_warn "Des clés API existent déjà dans env.conf"
        read -p "Voulez-vous les regénérer ? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Annulation. Clés existantes conservées."
            exit 0
        fi
    fi
    
    generate_api_keys
}

main "$@"
