#!/bin/bash
# Script de déploiement complet de Moodle
# Usage: ./7-deploy-moodle.sh [build|skip-build|reset-db]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARBOR_URL="192.168.20.205"
#HARBOR_URL="harbor.greencontracts.lan"
HARBOR_PROJECT="library"
IMAGE_NAME="moodle"
IMAGE_TAG="latest"
FULL_IMAGE="${HARBOR_URL}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"
DOCKER_DIR="${SCRIPT_DIR}/docker-images/moodle"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"

K3S_MANAGER="192.168.20.220"
K3S_USER="ubuntu"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Déploiement Moodle sur K3s${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================
# 1. BUILD IMAGE (optionnel)
# ============================================
if [[ "$1" != "skip-build" ]]; then
    echo -e "${BLUE}🔨 Étape 1: Build de l'image Docker...${NC}"
    
    # Build depuis la racine (contexte) avec Dockerfile explicite
    cd "${SCRIPT_DIR}"
    docker build -f docker-images/moodle/Dockerfile -t "${IMAGE_NAME}:${IMAGE_TAG}" .
    docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${FULL_IMAGE}"
    
    echo -e "${GREEN}✅ Image buildée: ${FULL_IMAGE}${NC}"
    echo ""
    
    # Push vers Harbor
    echo -e "${BLUE}📤 Étape 2: Push vers Harbor...${NC}"
    
    # Vérifier si loggé
    if ! docker info 2>/dev/null | grep -q "Username"; then
        echo -e "${YELLOW}🔑 Connexion Harbor requise${NC}"
        docker login "${HARBOR_URL}"
    fi
    
    docker push "${FULL_IMAGE}"
    echo -e "${GREEN}✅ Image poussée${NC}"
    echo ""
else
    echo -e "${YELLOW}⏭️ Build ignoré (skip-build)${NC}"
fi

# ============================================
# 2. RESET DB (optionnel)
# ============================================
if [[ "$1" == "reset-db" ]]; then
    echo -e "${BLUE}🗑️  Reset de la base de données...${NC}"
    
    # Supprimer le deployment pour éviter les connexions pendant le reset
    ssh -o StrictHostKeyChecking=no "${K3S_USER}@${K3S_MANAGER}" "sudo k3s kubectl delete deployment moodle -n moodle --ignore-not-found=true" 2>/dev/null || true
    
    # Reset DB via Ansible
    cd "${ANSIBLE_DIR}"
    ansible db-postgres-master -i inventories/dev/hosts.yml -m shell -a "
        sudo -u postgres psql -c 'DROP DATABASE IF EXISTS moodle;'
        sudo -u postgres psql -c 'DROP USER IF EXISTS moodle;'
    " 2>/dev/null || true
    
    # Recréer la base
    cd "${SCRIPT_DIR}"
    ./6-a-init-moodle-db.sh
    
    # Supprimer le marqueur d'installation du PVC
    ssh -o StrictHostKeyChecking=no "${K3S_USER}@${K3S_MANAGER}" "sudo k3s kubectl exec -n moodle deployment/moodle -- rm -f /var/www/moodledata/.installed 2>/dev/null || true"
    
    echo -e "${GREEN}✅ Base de données reset${NC}"
    echo ""
fi

# ============================================
# 3. SUPPRESSION ANCIEN DEPLOYMENT
# ============================================
echo -e "${BLUE}🧹 Étape 3: Suppression ancien deployment...${NC}"

ssh -o StrictHostKeyChecking=no "${K3S_USER}@${K3S_MANAGER}" "
    sudo k3s kubectl delete deployment moodle -n moodle --ignore-not-found=true
    sleep 2
"

echo -e "${GREEN}✅ Ancien deployment supprimé${NC}"
echo ""

# ============================================
# 4. DÉPLOIEMENT ANSIBLE
# ============================================
echo -e "${BLUE}🚀 Étape 4: Déploiement Ansible...${NC}"

cd "${ANSIBLE_DIR}"
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_moodle.yml

echo -e "${GREEN}✅ Déploiement Ansible terminé${NC}"
echo ""

# ============================================
# 5. VÉRIFICATION
# ============================================
echo -e "${BLUE}⏳ Étape 5: Vérification...${NC}"

sleep 10

# Attendre que le pod soit prêt
for i in {1..30}; do
    POD_STATUS=$(ssh -o StrictHostKeyChecking=no "${K3S_USER}@${K3S_MANAGER}" "sudo k3s kubectl get pod -n moodle -l app=moodle -o jsonpath='{.items[0].status.phase}'" 2>/dev/null || echo "Unknown")
    
    if [[ "${POD_STATUS}" == "Running" ]]; then
        READY=$(ssh -o StrictHostKeyChecking=no "${K3S_USER}@${K3S_MANAGER}" "sudo k3s kubectl get pod -n moodle -l app=moodle -o jsonpath='{.items[0].status.containerStatuses[0].ready}'" 2>/dev/null || echo "false")
        if [[ "${READY}" == "true" ]]; then
            echo -e "${GREEN}✅ Pod Moodle prêt !${NC}"
            break
        fi
    fi
    
    if [[ $i -eq 30 ]]; then
        echo -e "${RED}❌ Timeout: Le pod n'est pas prêt${NC}"
        ssh -o StrictHostKeyChecking=no "${K3S_USER}@${K3S_MANAGER}" "sudo k3s kubectl logs -n moodle deployment/moodle --tail=20" 2>/dev/null || true
        exit 1
    fi
    
    echo -n "."
    sleep 3
done

echo ""
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ Moodle déployé avec succès !${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "🔗 Accès par IP:   ${BLUE}http://192.168.20.220:30081${NC}"
echo -e "🔗 Accès par URL:  ${BLUE}http://moodle.greencontracts.lan${NC}"
echo ""
echo -e "📋 Commandes utiles:"
echo -e "   Logs:    ssh ${K3S_USER}@${K3S_MANAGER} 'sudo k3s kubectl logs -n moodle deployment/moodle -f'"
echo -e "   Shell:   ssh ${K3S_USER}@${K3S_MANAGER} 'sudo k3s kubectl exec -n moodle deployment/moodle -it -- bash'"
echo -e "   Status:  ssh ${K3S_USER}@${K3S_MANAGER} 'sudo k3s kubectl get pods -n moodle'"
echo ""
