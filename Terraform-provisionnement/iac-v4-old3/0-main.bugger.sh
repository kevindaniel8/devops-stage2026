#!/bin/bash
set -euo pipefail

############################################
# CHARGEMENT CONFIG GLOBALE
############################################
ENV_FILE="${ENV_FILE:-./env.conf}"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    echo "✅ Configuration globale chargée: $ENV_FILE"
fi

############################################
# CONFIG (avec fallback sur env.conf)
############################################
PROXMOX_HOST="${PM_HOST:-192.168.0.1}"
PROXMOX_USER="${PM_SSH_USER:-root}"

SCRIPT1="./1-generate-ssh-keys.sh"
SCRIPT2="./2-create-user-proxmox.sh"
SCRIPT3="./3-cloud-init-images.sh"
SCRIPT4="./4-template-generique.sh"
SCRIPT5="./5-generate-terraform-config.sh"

SSH_KEY_PATH="./ssh/id_ed25519_terraform-proxmox.pub"

# Argument pour le script 3 (debian, 24.04, 26.04, ou all)
# Peut être défini via env.conf ou argument ligne de commande
SCRIPT3_ARG="${1:-${SCRIPT3_ARG:-all}}"
#SCRIPT3_ARG="${1:-debian}"

REMOTE_DIR="${REMOTE_DIR:-/home/kevin-stage-devops}"
REMOTE_SCRIPT2="$REMOTE_DIR/2-create-user-proxmox.sh"
REMOTE_SCRIPT3="$REMOTE_DIR/3-cloud-init-images.sh"
REMOTE_SCRIPT4="$REMOTE_DIR/4-template-generique.sh"

############################################
# SSH MULTIPLEXING
############################################
SSH_CTRL_DIR="$HOME/.ssh/ctrl"
mkdir -p "$SSH_CTRL_DIR"
SSH_CTRL_SOCKET="$SSH_CTRL_DIR/proxmox-ctrl-%r@%h:%p"

SSH_OPTS="-o ControlMaster=auto -o ControlPersist=10m -o ControlPath=$SSH_CTRL_SOCKET"

echo "🔌 Activation du multiplexing SSH..."

############################################
# 1. EXECUTION DU SCRIPT 1 EN LOCAL
############################################
echo "▶️  Exécution du script 1 (génération des clés SSH)..."
bash "$SCRIPT1"

if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo "❌ ERREUR : clé publique introuvable : $SSH_KEY_PATH"
    exit 1
fi

SSH_PUBLIC_KEY_CONTENT="$(cat "$SSH_KEY_PATH")"
echo "✔️  Clé publique récupérée."

############################################
# 2. COPIE DES SCRIPTS SUR PROXMOX
############################################
echo "📁 Création du dossier distant sur Proxmox..."
ssh $SSH_OPTS "${PROXMOX_USER}@${PROXMOX_HOST}" "mkdir -p $REMOTE_DIR"

echo "📤 Envoi des scripts vers Proxmox..."
scp $SSH_OPTS "$SCRIPT2" "${PROXMOX_USER}@${PROXMOX_HOST}:${REMOTE_SCRIPT2}"
scp $SSH_OPTS "$SCRIPT3" "${PROXMOX_USER}@${PROXMOX_HOST}:${REMOTE_SCRIPT3}"
scp $SSH_OPTS "$SCRIPT4" "${PROXMOX_USER}@${PROXMOX_HOST}:${REMOTE_SCRIPT4}"

############################################
# 3. PERMISSIONS
############################################
echo "🔧 Application des permissions..."
ssh $SSH_OPTS "${PROXMOX_USER}@${PROXMOX_HOST}" "chmod +x ${REMOTE_SCRIPT2} ${REMOTE_SCRIPT3} ${REMOTE_SCRIPT4}"

############################################
# 4. EXECUTION DU SCRIPT 2 (création user)
############################################
echo "🚀 Exécution du script 2 sur Proxmox..."
ssh $SSH_OPTS "${PROXMOX_USER}@${PROXMOX_HOST}" \
    "${REMOTE_SCRIPT2} \"${SSH_PUBLIC_KEY_CONTENT}\""

############################################
# 5. EXECUTION DU SCRIPT 3 (téléchargement images cloud)
############################################
echo "☁️  Téléchargement des images Cloud-init sur Proxmox (mode: $SCRIPT3_ARG)..."
ssh $SSH_OPTS "${PROXMOX_USER}@${PROXMOX_HOST}" "${REMOTE_SCRIPT3} ${SCRIPT3_ARG}"

############################################
# 6. EXECUTION DU SCRIPT 4 (création templates)
############################################
echo "📦 Création des templates Proxmox..."
ssh $SSH_OPTS "${PROXMOX_USER}@${PROXMOX_HOST}" "${REMOTE_SCRIPT4}"

############################################
# 7. GÉNÉRATION CONFIG TERRAFORM (toujours exécutée)
############################################
echo "⚙️  Régénération forcée de la configuration Terraform..."
if [[ -f "$SCRIPT5" ]]; then
    # Utiliser le chemin absolu pour être sûr
    bash "$SCRIPT5"
    echo "✔️  Configuration Terraform régénérée avec succès."
else
    echo "❌ ERREUR: Script 5 non trouvé: $SCRIPT5"
    exit 1
fi

############################################
# 8. SUPPRESSION VMs EXISTANTES (idempotence)
############################################
echo ""
echo "🔍 [8.1] Récupération des VMID depuis terraform.tfvars..."

TERRAFORM_DIR="./Terraform"

# Récupérer les VMID depuis terraform.tfvars (vmid_start + index)
VMID_START=$(grep "vmid_start" "$TERRAFORM_DIR/terraform.tfvars" 2>/dev/null | grep -o '[0-9]\+' | head -1)
VMID_START="${VMID_START:-200}"

# Compter le nombre de VMs dans vm_definitions
VM_COUNT=$(grep -c "= {" "$TERRAFORM_DIR/terraform.tfvars" 2>/dev/null || echo "0")

if [[ "$VM_COUNT" -gt 0 ]]; then
    echo "📋 [8.2] VMID cibles (à recréer): $VMID_START - $((VMID_START + VM_COUNT - 1))"
    
    # Vérifier chaque VMID sur Proxmox
    echo "🔍 [8.3] Vérification des VMs existantes sur Proxmox..."
    for ((i=0; i<VM_COUNT; i++)); do
        VMID=$((VMID_START + i))
        VM_EXISTS=$(ssh $SSH_OPTS "${PROXMOX_USER}@${PROXMOX_HOST}" "qm status $VMID 2>/dev/null | grep -E 'running|stopped' || echo ''" 2>/dev/null)
        
        if [[ -n "$VM_EXISTS" ]]; then
            echo "   ⚠️  VM $VMID existe (${VM_EXISTS}) → suppression..."
            ssh $SSH_OPTS "${PROXMOX_USER}@${PROXMOX_HOST}" "qm stop $VMID 2>/dev/null; qm destroy $VMID --purge 2>/dev/null" 2>/dev/null || true
            echo "   ✅ VM $VMID supprimée"
        fi
    done
    echo "🧹 [8.4] Nettoyage des VMs terminé"
else
    echo "⚠️  [8.2] Impossible de détecter les VMID depuis terraform.tfvars"
fi

############################################
# 9. DÉPLOIEMENT TERRAFORM (optionnel)
############################################
if [[ -d "$TERRAFORM_DIR" ]] && command -v terraform &> /dev/null; then
    echo ""
    read -p "🚀 [9.0] Lancer le déploiement Terraform maintenant ? (y/N) : " RUN_TERRAFORM
    if [[ "$RUN_TERRAFORM" =~ ^[Yy]$ ]]; then
        cd "$TERRAFORM_DIR"
        
        echo "🧹 [9.1] Nettoyage du state Terraform (destroy/recreate)..."
        # Vérifier et supprimer uniquement si les fichiers existent
        if ls terraform.tfstate* .terraform.lock.hcl >/dev/null 2>&1; then
            rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl 2>/dev/null
            echo "   ✅ Fichiers d'état Terraform supprimés"
        else
            echo "   ℹ️  Aucun fichier d'état à supprimer"
        fi
        
        if [ -d ".terraform" ]; then
            rm -rf .terraform/ 2>/dev/null
            echo "   ✅ Cache provider Terraform supprimé"
        else
            echo "   ℹ️  Aucun cache provider à supprimer"
        fi
        
        echo "🔄 [9.2] Initialisation Terraform..."
        terraform init
        
        echo "🔄 [9.3] Rafraîchissement de l'état (sync avec Proxmox)..."
        terraform refresh 2>/dev/null || echo "⚠️  Certains VMs peuvent avoir été supprimées manuellement"
        
        echo "📋 [9.4] Planification..."
        terraform plan -out=tfplan
        
        read -p "✅ [9.5] Confirmer l'application ? (y/N) : " CONFIRM_APPLY
        if [[ "$CONFIRM_APPLY" =~ ^[Yy]$ ]]; then
            echo "🚀 [9.6] Application des changements..."
            terraform apply tfplan
            echo "🎉 Déploiement Terraform terminé avec succès !"
            
            # =============================================================================
            # ÉTAPE 10: Déploiement Ansible
            # =============================================================================
            echo ""
            echo "🚀 [10.0] Lancement du déploiement Ansible..."
            cd ..
            if [ -f "./6-deploiement-ansible.sh" ]; then
                read -p "🚀 [10.1] Déployer la configuration Ansible maintenant ? (y/N) : " CONFIRM_ANSIBLE
                if [[ "$CONFIRM_ANSIBLE" =~ ^[Yy]$ ]]; then
                    echo "🚀 [10.2] Exécution du déploiement Ansible..."
                    ./6-deploiement-ansible.sh
                else
                    echo "⏸️  Déploiement Ansible ignoré."
                    echo "   Pour déployer manuellement : ./6-deploiement-ansible.sh"
                fi
            else
                echo "⚠️  Script 6-deploiement-ansible.sh non trouvé"
                echo "   Pour déployer manuellement : ./6-deploiement-ansible.sh"
            fi
        else
            echo "⏸️  Déploiement annulé. Plan sauvegardé dans tfplan"
            echo "   Pour déployer manuellement :"
            echo "   cd $TERRAFORM_DIR && terraform apply tfplan"
            echo "   ./6-deploiement-ansible.sh"
        fi
        cd ..
    else
        echo "⏭️  Pour déployer manuellement :"
        echo "   cd $TERRAFORM_DIR && terraform init && terraform plan && terraform apply"
        echo "   ./6-deploiement-ansible.sh"
    fi
else
    echo "⏭️  Terraform non disponible. Pour déployer manuellement :"
    echo "   cd $TERRAFORM_DIR && terraform init && terraform plan && terraform apply"
    echo "   ./6-deploiement-ansible.sh"
fi

echo ""
echo "🎉 Pipeline IaC terminé avec succès."
