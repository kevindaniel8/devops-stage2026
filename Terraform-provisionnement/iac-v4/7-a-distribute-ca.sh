#!/bin/bash
# Script de distribution de la CA GreenContracts aux clients
# Topologie réseau :
#   - 192.168.20.0/24 : Réseau PVE (VMs : reverse-proxy, harbor, k3s-manager, pc-management)
#   - 192.168.0.0/24 : Réseau local box (PC de dev, futurs utilisateurs)
#
# Usage: ./7-a-distribute-ca.sh [ssh|http|manual] [user@IP|hostname]
#
# Modes:
#   ssh    : Distribution via SSH (nécessite accès SSH aux cibles)
#   http   : Téléchargement depuis un serveur HTTP (nécessite serveur web)
#   manual : Installation locale (à exécuter sur chaque machine)
#
# Exemples:
#   ./7-a-distribute-ca.sh ssh kevin@192.168.20.5
#   ./7-a-distribute-ca.sh ssh 192.168.0.10
#   ./7-a-distribute-ca.sh http https://ca.greencontracts.lan/ca.crt
#   ./7-a-distribute-ca.sh manual

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CA_FILE="${SCRIPT_DIR}/ansible/files/pki/ca/ca.crt"
CA_NAME="greencontracts-ca.crt"
CA_DEST="/usr/local/share/ca-certificates/${CA_NAME}"

# Vérifier que la CA existe
if [[ ! -f "${CA_FILE}" ]]; then
    echo -e "${RED}❌ Erreur: Fichier CA non trouvé: ${CA_FILE}${NC}"
    exit 1
fi

MODE="${1:-manual}"
TARGET="${2:-}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Distribution CA GreenContracts${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Mode: ${MODE}${NC}"
echo ""

case "${MODE}" in
    ssh)
        if [[ -z "${TARGET}" ]]; then
            echo -e "${RED}❌ Erreur: Mode SSH nécessite une cible (IP ou hostname)${NC}"
            echo -e "${YELLOW}Usage: ./distribute-ca.sh ssh <IP|hostname>${NC}"
            exit 1
        fi

        echo -e "${BLUE}📤 Distribution via SSH vers ${TARGET}...${NC}"
        
        # Copier la CA via SCP dans le home directory
        scp "${CA_FILE}" "${TARGET}:~/${CA_NAME}"
        
        echo -e "${YELLOW}⚠️  CA copiée dans le home directory de ${TARGET}${NC}"
        echo -e "${YELLOW}⚠️  Exécutez cette commande sur ${TARGET} pour installer la CA:${NC}"
        echo -e "${GREEN}sudo mkdir -p /usr/local/share/ca-certificates && sudo cp ~/${CA_NAME} /usr/local/share/ca-certificates/ && sudo update-ca-certificates && rm ~/${CA_NAME}${NC}"
        
        # Tenter l'installation automatique
        ssh "${TARGET}" "sudo mkdir -p /usr/local/share/ca-certificates && sudo cp ~/${CA_NAME} /usr/local/share/ca-certificates/ && sudo update-ca-certificates && rm ~/${CA_NAME}" 2>&1
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ CA distribuée et installée sur ${TARGET}${NC}"
        else
            echo -e "${RED}❌ Échec de l'installation automatique${NC}"
            echo -e "${YELLOW}Exécutez manuellement la commande ci-dessus sur ${TARGET}${NC}"
        fi
        ;;
        
    http)
        if [[ -z "${TARGET}" ]]; then
            echo -e "${RED}❌ Erreur: Mode HTTP nécessite une URL${NC}"
            echo -e "${YELLOW}Usage: ./distribute-ca.sh http <URL_CA>${NC}"
            exit 1
        fi

        echo -e "${BLUE}📥 Téléchargement depuis ${TARGET}...${NC}"
        
        # Télécharger la CA
        curl -f -o "/tmp/${CA_NAME}" "${TARGET}"
        
        # Installer la CA
        sudo cp "/tmp/${CA_NAME}" "${CA_DEST}"
        sudo update-ca-certificates
        rm "/tmp/${CA_NAME}"
        
        echo -e "${GREEN}✅ CA installée avec succès${NC}"
        ;;
        
    manual)
        echo -e "${BLUE}🔧 Installation locale de la CA...${NC}"
        
        # Installer la CA localement
        sudo cp "${CA_FILE}" "${CA_DEST}"
        sudo update-ca-certificates
        
        echo -e "${GREEN}✅ CA installée avec succès${NC}"
        echo ""
        echo -e "${YELLOW}📋 Pour vérifier l'installation:${NC}"
        echo -e "   ls -la /usr/local/share/ca-certificates/${CA_NAME}"
        echo -e "   sudo update-ca-certificates --fresh"
        ;;
        
    *)
        echo -e "${RED}❌ Erreur: Mode inconnu: ${MODE}${NC}"
        echo -e "${YELLOW}Modes disponibles: ssh, http, manual${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ Opération terminée${NC}"
echo -e "${GREEN}========================================${NC}"
