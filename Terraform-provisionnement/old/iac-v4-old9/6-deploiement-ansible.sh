#!/bin/bash
# =============================================================================
# Script: 6-deploiement-ansible.sh
# Description: Déploiement Ansible avec menu interactif ou exécution directe
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================
ENV_FILE="${ENV_FILE:-./env.conf}"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

# Chemins Ansible
ANSIBLE_DIR="${ANSIBLE_DIR:-./ansible}"
PLAYBOOKS_DIR="${ANSIBLE_PLAYBOOKS_DIR:-$ANSIBLE_DIR/playbooks}"
INVENTORY="${ANSIBLE_INVENTORY:-inventories/dev/hosts.yml}"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# FONCTION: Exécuter un playbook spécifique
# Usage: run_playbook <nom_du_playbook>
# =============================================================================
run_playbook() {
    local playbook="$1"
    local playbook_path="$PLAYBOOKS_DIR/${playbook}.yml"
    
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${BLUE}  Exécution: ${playbook}${NC}"
    echo -e "${BLUE}===============================================${NC}"
    
    if [ ! -f "$playbook_path" ]; then
        echo -e "${RED}❌ Erreur: Playbook non trouvé: $playbook_path${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📋 Inventory: $ANSIBLE_DIR/$INVENTORY${NC}"
    echo -e "${CYAN}📋 Playbook: $playbook_path${NC}"
    echo ""
    
    cd "$ANSIBLE_DIR" && ansible-playbook -i "$INVENTORY" "playbooks/${playbook}.yml"
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ Playbook ${playbook} exécuté avec succès${NC}"
    else
        echo -e "${RED}❌ Échec du playbook ${playbook} (exit code: $exit_code)${NC}"
    fi
    return $exit_code
}

# =============================================================================
# FONCTION: Déploiement complet (deploy_all)
# =============================================================================
deploy_all() {
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${BLUE}  DÉPLOIEMENT COMPLET - ALL ROLES${NC}"
    echo -e "${BLUE}===============================================${NC}"
    
    run_playbook "deploy_all"
}

# =============================================================================
# FONCTION: Menu interactif
# =============================================================================
show_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     MENU DÉPLOIEMENT ANSIBLE - IAC-V3          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Playbooks disponibles:${NC}"
    echo ""
    echo "  [0] 🚀  Déploiement COMPLET (deploy_all)"
    echo "  [1] 📦  Pipeline CD (Harbor + K3s + ArgoCD)"
    echo "  [2] 🐘  Cluster PostgreSQL (Master + Replica)"
    echo "  [3] 🌐  DNS (Bind9)"
    echo "  [4] 🔄  Reverse Proxy"
    echo "  [5] 📚  WikiJS"
    echo "  [6] 📊  SNMP Monitoring"
    echo ""
    echo -e "${YELLOW}Autres options:${NC}"
    echo "  [97] 🧹  Syntax-check all playbooks"
    echo "  [98] 📋  Lister les playbooks disponibles"
    echo "  [99] ❌  Quitter"
    echo ""
    echo -n "Choix [0-99]: "
}

# =============================================================================
# FONCTION: Menu principal
# =============================================================================
menu_mode() {
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            0) deploy_all; break ;;
            1) run_playbook "pipeline_cd"; break ;;
            2) run_playbook "cluster-postgres"; break ;;
            3) run_playbook "deploy_dns"; break ;;
            4) run_playbook "deploy_reverse_proxy"; break ;;
            5) run_playbook "deploy_wikijs"; break ;;
            6) run_playbook "deploy_snmp"; break ;;
            97) syntax_check_all ;;
            98) list_playbooks ;;
            99) echo -e "${GREEN}👋 Au revoir!${NC}"; exit 0 ;;
            *) echo -e "${RED}❌ Option invalide${NC}"; sleep 1 ;;
        esac
    done
}

# =============================================================================
# FONCTION: Syntax-check de tous les playbooks
# =============================================================================
syntax_check_all() {
    echo -e "${YELLOW}🔍 Vérification syntaxique des playbooks...${NC}"
    
    for playbook in "$PLAYBOOKS_DIR"/*.yml; do
        if [ -f "$playbook" ]; then
            local name=$(basename "$playbook" .yml)
            echo -n "  Checking ${name}... "
            if cd "$ANSIBLE_DIR" && ansible-playbook -i "$INVENTORY" "playbooks/${name}.yml" --syntax-check > /dev/null 2>&1; then
                echo -e "${GREEN}OK${NC}"
            else
                echo -e "${RED}FAILED${NC}"
            fi
        fi
    done
}

# =============================================================================
# FONCTION: Lister les playbooks disponibles
# =============================================================================
list_playbooks() {
    echo -e "${YELLOW}📋 Playbooks disponibles dans $PLAYBOOKS_DIR:${NC}"
    echo ""
    ls -1 "$PLAYBOOKS_DIR"/*.yml 2>/dev/null | while read -r playbook; do
        echo "  - $(basename "$playbook")"
    done
    echo ""
}

# =============================================================================
# FONCTION: Afficher l'aide
# =============================================================================
show_help() {
    cat << EOF
Usage: $0 [OPTION|PLAYBOOK...]

Options:
  -h, --help, -?        Afficher cette aide
  -m, --menu            Lancer le menu interactif (défaut si aucun paramètre)
  -l, --list            Lister les playbooks disponibles
  -c, --check           Syntax-check tous les playbooks

Playbooks (exécution directe - un ou plusieurs):
  deploy_all            Déploiement complet (par défaut)
  pipeline_cd           Harbor + K3s + ArgoCD
  cluster-postgres      PostgreSQL Master + Replica
  deploy_dns            DNS Bind9
  deploy_reverse_proxy  Reverse Proxy
  deploy_wikijs         WikiJS
  deploy_snmp           SNMP Monitoring

Exemples:
  $0                    # Déploie tout (deploy_all) - COMPORTEMENT PAR DÉFAUT
  $0 deploy_all         # Déploie tout explicitement
  $0 pipeline_cd        # Déploie uniquement le pipeline CD
  $0 pipeline_cd cluster-postgres  # Déploie 2 playbooks en séquence
  $0 -m                 # Lance le menu interactif
  $0 -l                 # Liste les playbooks

EOF
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================
main() {
    # Si aucun paramètre → déploiement complet par défaut
    if [ $# -eq 0 ]; then
        echo -e "${YELLOW}ℹ️  Aucun paramètre fourni → Déploiement complet par défaut${NC}"
        deploy_all
        exit $?
    fi
    
    # Vérifier si premier argument est une option
    case "$1" in
        -h|--help|-\?)
            show_help
            exit 0
            ;;
        -m|--menu)
            menu_mode
            exit 0
            ;;
        -l|--list)
            list_playbooks
            exit 0
            ;;
        -c|--check)
            syntax_check_all
            exit 0
            ;;
    esac
    
    # Exécution de un ou plusieurs playbooks
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${BLUE}  EXÉCUTION MULTIPLE - $# PLAYBOOK(S)${NC}"
    echo -e "${BLUE}===============================================${NC}"
    echo ""
    
    local exit_code=0
    for playbook in "$@"; do
        run_playbook "$playbook" || exit_code=$?
        echo ""
    done
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ Tous les playbooks ont été exécutés avec succès${NC}"
    else
        echo -e "${RED}❌ Certains playbooks ont échoué${NC}"
    fi
    exit $exit_code
}

main "$@"
