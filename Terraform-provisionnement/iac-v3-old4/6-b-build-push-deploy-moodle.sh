#!/bin/bash
# Build, Push, Init DB et Déploiement de Moodle
# Usage: ./6-b-build-push-deploy-moodle.sh [skip-build] [skip-push] [skip-db-init] [skip-deploy]

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Détection du répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="${SCRIPT_DIR}/docker-images/moodle"
ANSIBLE_SCRIPT="${SCRIPT_DIR}/6-deploiement-ansible.sh"
INIT_DB_SCRIPT="${SCRIPT_DIR}/6-a-init-moodle-db.sh"

# Configuration
HARBOR_URL="192.168.20.205"
HARBOR_PROJECT="library"
IMAGE_NAME="moodle"
IMAGE_TAG="latest"
FULL_IMAGE="${HARBOR_URL}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"

# Flags
SKIP_BUILD=false
SKIP_PUSH=false
SKIP_DB_INIT=false
SKIP_DEPLOY=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        skip-build) SKIP_BUILD=true ;;
        skip-push) SKIP_PUSH=true ;;
        skip-db-init) SKIP_DB_INIT=true ;;
        skip-deploy) SKIP_DEPLOY=true ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Build, Push & Deploy Moodle${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Vérification des prérequis
check_prereqs() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker n'est pas installé${NC}"
        exit 1
    fi
    
    if [ ! -d "${DOCKER_DIR}" ]; then
        echo -e "${RED}❌ Répertoire ${DOCKER_DIR} introuvable${NC}"
        exit 1
    fi
    
    if [ ! -f "${ANSIBLE_SCRIPT}" ]; then
        echo -e "${RED}❌ Script Ansible ${ANSIBLE_SCRIPT} introuvable${NC}"
        exit 1
    fi
    
    if [ ! -f "${INIT_DB_SCRIPT}" ]; then
        echo -e "${RED}❌ Script init DB ${INIT_DB_SCRIPT} introuvable${NC}"
        exit 1
    fi
}

# Init DB
init_db() {
    if [ "$SKIP_DB_INIT" = true ]; then
        echo -e "${YELLOW}⏭️  Init DB ignoré (skip-db-init)${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🔧 Étape 0/5: Initialisation de la base PostgreSQL...${NC}"
    "${INIT_DB_SCRIPT}"
    echo ""
}

# Build de l'image
build_image() {
    if [ "$SKIP_BUILD" = true ]; then
        echo -e "${YELLOW}⏭️  Build ignoré (skip-build)${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🔨 Étape 1/5: Build de l'image...${NC}"
    # debut modif a retirer si pas fonctionnel
    #docker build -t "moodle-custom:latest" "${DOCKER_DIR}"
    docker build \
      -t "moodle-custom:latest" \
      -f "${DOCKER_DIR}/Dockerfile" \
      "${SCRIPT_DIR}"
    # fin modif a retiré si pas fonctionnel

    echo -e "${GREEN}✅ Image buildée: moodle-custom:latest${NC}"
    echo ""
}

# Tag de l'image
tag_image() {
    if [ "$SKIP_BUILD" = true ] && [ "$SKIP_PUSH" = true ]; then
        return 0
    fi
    
    echo -e "${BLUE}🏷️  Étape 2/5: Tag de l'image...${NC}"
    docker tag "moodle-custom:latest" "${FULL_IMAGE}"
    echo -e "${GREEN}✅ Image taggée: ${FULL_IMAGE}${NC}"
    echo ""
}

# Push vers Harbor
push_image() {
    if [ "$SKIP_PUSH" = true ]; then
        echo -e "${YELLOW}⏭️  Push ignoré (skip-push)${NC}"
        return 0
    fi
    
    echo -e "${BLUE}📤 Étape 3/5: Push vers Harbor...${NC}"
    
    if ! docker info 2>/dev/null | grep -q "Username"; then
        echo -e "${YELLOW}🔑 Login Harbor requis${NC}"
        docker login "${HARBOR_URL}"
    fi
    
    docker push "${FULL_IMAGE}"
    echo -e "${GREEN}✅ Image poussée sur ${HARBOR_URL}${NC}"
    echo ""
}

# Suppression du deployment
cleanup_deployment() {
    if [ "$SKIP_DEPLOY" = true ]; then
        return 0
    fi
    
    echo -e "${BLUE}🧹 Étape 4/5: Suppression de l'ancien deployment...${NC}"
    
    K3S_MANAGER_IP="192.168.20.220"
    K3S_USER="ubuntu"
    
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${K3S_USER}@${K3S_MANAGER_IP}" "sudo k3s kubectl delete deployment moodle -n moodle 2>/dev/null || echo 'DEPLOYMENT_NOT_FOUND'" 2>/dev/null | grep -q "deleted\|DEPLOYMENT_NOT_FOUND"; then
        echo -e "${GREEN}✅ Deployment supprimé automatiquement${NC}"
    else
        echo -e "${YELLOW}⚠️  Échec suppression auto${NC}"
        echo -e "   ${YELLOW}sudo k3s kubectl delete deployment moodle -n moodle${NC}"
        read -p "Appuyez sur Entrée après avoir exécuté la commande..."
    fi
    echo ""
}

# Déploiement
deploy() {
    if [ "$SKIP_DEPLOY" = true ]; then
        echo -e "${YELLOW}⏭️  Déploiement ignoré (skip-deploy)${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🚀 Étape 5/5: Déploiement sur K3s...${NC}"
    "${ANSIBLE_SCRIPT}" deploy_moodle
    echo -e "${GREEN}✅ Déploiement terminé${NC}"
}

# Affichage de l'aide
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  skip-build     - Ignorer le build"
    echo "  skip-push      - Ignorer le push"
    echo "  skip-db-init   - Ignorer l'init DB"
    echo "  skip-deploy    - Ignorer le déploiement"
    echo ""
    echo "Exemples:"
    echo "  $0                     - Complet (DB + Build + Push + Deploy)"
    echo "  $0 skip-db-init        - Build + Push + Deploy (DB déjà faite)"
    echo "  $0 skip-build          - Push + Deploy (image déjà buildée)"
    echo "  $0 skip-push           - Build + Deploy (sans Harbor)"
    echo ""
}

# Main
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

check_prereqs
init_db
build_image
tag_image
push_image
cleanup_deployment
deploy

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ Moodle déployé avec succès !${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "🔗 URL Moodle: ${BLUE}http://192.168.20.220:30081${NC}"
echo ""
