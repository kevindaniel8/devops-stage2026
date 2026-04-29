#!/bin/bash

set -e

# =============================================================================
# 4-0-template-generique.sh - Fonction modulaire pour créer des templates
# =============================================================================
# Utilisation:
#   1. Ligne de commande: ./4-0-template-generique.sh 9001 debian-13 /path/image.qcow2
#   2. Source dans script: source ./4-0-template-generique.sh && create_template 9001 ...
# =============================================================================

# Valeurs par défaut
DEFAULT_VM_ID="9001"
DEFAULT_VM_NAME="debian-13-cloud"
DEFAULT_IMAGE_PATH="/var/lib/vz/template/cloud-init-images/debian-13-generic-amd64.qcow2"
DEFAULT_STORAGE="local-lvm"
DEFAULT_BRIDGE="vmbr0"
DEFAULT_MEMORY="2048"
DEFAULT_CORES="1"
DEFAULT_DISK_SIZE="10G"

# Répertoire de recherche des images
IMAGE_SEARCH_DIR="/var/lib/vz/template/cloud-init-images"

# =============================================================================
# FONCTION: find_image
# Description: Recherche une image cloud-init avec fallback par pattern
# Arguments: type (debian|ubuntu24|ubuntu26)
# Retour: chemin complet de l'image trouvée ou chaîne vide
# =============================================================================
find_image() {
    local image_type="$1"
    local search_dir="${2:-$IMAGE_SEARCH_DIR}"
    local min_size=100000000  # 100MB minimum
    
    # Vérifier que le dossier existe
    if [ ! -d "$search_dir" ]; then
        echo ""
        return 1
    fi
    
    case "$image_type" in
        debian)
            # 1. Nom exact attendu
            local exact_file="$search_dir/debian-13-generic-amd64.qcow2"
            if [ -f "$exact_file" ]; then
                local size=$(stat -f%z "$exact_file" 2>/dev/null || stat -c%s "$exact_file" 2>/dev/null || echo 0)
                if [ "$size" -gt "$min_size" ]; then
                    echo "$exact_file"
                    return 0
                fi
            fi
            # 2. Pattern fallback: *debian*13*.qcow2
            local found
            found=$(find "$search_dir" -maxdepth 1 -type f -iname "*debian*13*.qcow2" 2>/dev/null | head -1)
            if [ -n "$found" ] && [ -f "$found" ]; then
                echo "$found"
                return 0
            fi
            ;;
            
        ubuntu24|ubuntu-24|24.04|noble)
            # 1. Nom exact attendu
            local exact_file="$search_dir/ubuntu-24.04-server-cloudimg-amd64.img"
            if [ -f "$exact_file" ]; then
                local size=$(stat -f%z "$exact_file" 2>/dev/null || stat -c%s "$exact_file" 2>/dev/null || echo 0)
                if [ "$size" -gt "$min_size" ]; then
                    echo "$exact_file"
                    return 0
                fi
            fi
            # 2. Pattern fallback: *noble*.img OU *ubuntu*24*.img
            local found
            found=$(find "$search_dir" -maxdepth 1 -type f \( -iname "*noble*.img" -o -iname "*ubuntu*24*.img" \) 2>/dev/null | head -1)
            if [ -n "$found" ] && [ -f "$found" ]; then
                echo "$found"
                return 0
            fi
            ;;
            
        ubuntu26|ubuntu-26|26.04|resolute)
            # 1. Nom exact attendu
            local exact_file="$search_dir/ubuntu-26.04-server-cloudimg-amd64.img"
            if [ -f "$exact_file" ]; then
                local size=$(stat -f%z "$exact_file" 2>/dev/null || stat -c%s "$exact_file" 2>/dev/null || echo 0)
                if [ "$size" -gt "$min_size" ]; then
                    echo "$exact_file"
                    return 0
                fi
            fi
            # 2. Pattern fallback: *resolute*.img OU *ubuntu*26*.img
            local found
            found=$(find "$search_dir" -maxdepth 1 -type f \( -iname "*resolute*.img" -o -iname "*ubuntu*26*.img" \) 2>/dev/null | head -1)
            if [ -n "$found" ] && [ -f "$found" ]; then
                echo "$found"
                return 0
            fi
            ;;
    esac
    
    # Aucune image trouvée
    echo ""
    return 1
}

# =============================================================================
# FONCTION: create_template
# Description: Crée un template Proxmox à partir d'une image cloud-init
# Arguments: vm_id, vm_name, image_path, [storage], [bridge], [memory], [cores], [disk_size]
# =============================================================================
create_template() {
    # Récupération des paramètres avec valeurs par défaut
    local VM_ID="${1:-$DEFAULT_VM_ID}"
    local VM_NAME="${2:-$DEFAULT_VM_NAME}"
    local IMAGE_PATH="${3:-$DEFAULT_IMAGE_PATH}"
    local STORAGE="${4:-$DEFAULT_STORAGE}"
    local BRIDGE="${5:-$DEFAULT_BRIDGE}"
    local MEMORY="${6:-$DEFAULT_MEMORY}"
    local CORES="${7:-$DEFAULT_CORES}"
    local DISK_SIZE="${8:-$DEFAULT_DISK_SIZE}"
    
    # =====================
    # VALIDATION
    # =====================
    if [ -z "$IMAGE_PATH" ]; then
        echo "❌ Usage: create_template <vm_id> <vm_name> <image_path> [storage] [bridge]"
        return 1
    fi
    
    if [ ! -f "$IMAGE_PATH" ]; then
        echo "❌ Image introuvable : $IMAGE_PATH"
        return 1
    fi
    
    echo "==============================="
    echo "🚀 Création template Proxmox"
    echo "==============================="
    echo "VM ID      : $VM_ID"
    echo "VM Name    : $VM_NAME"
    echo "Image      : $IMAGE_PATH"
    echo "Storage    : $STORAGE"
    echo "Bridge     : $BRIDGE"
    echo "==============================="
    
    # =====================
    # CLEAN EXISTING VM
    # =====================
    if qm status $VM_ID &>/dev/null; then
        echo "⚠️ VM existe déjà → suppression..."
        qm destroy $VM_ID --purge || true
    fi
    
    # =====================
    # CREATE VM
    # =====================
    echo "🛠️ Création VM..."
    qm create $VM_ID \
        --name $VM_NAME \
        --memory $MEMORY \
        --cores $CORES \
        --net0 virtio,bridge=$BRIDGE \
        --description "Cloud-init template auto-generated"
    
    # =====================
    # IMPORT DISK
    # =====================
    echo "📦 Import du disque..."
    qm importdisk $VM_ID "$IMAGE_PATH" $STORAGE
    
    # =====================
    # ATTACH DISK
    # =====================
    echo "💽 Attachement disque..."
    qm set $VM_ID \
        --scsihw virtio-scsi-pci \
        --scsi0 $STORAGE:vm-$VM_ID-disk-0
    
    # =====================
    # CLOUD-INIT CONFIG
    # =====================
    echo "☁️ Configuration cloud-init..."
    qm set $VM_ID \
        --ide2 $STORAGE:cloudinit \
        --boot order=scsi0 \
        --serial0 socket \
        --vga serial0
    
    # =====================
    # RESIZE DISK
    # =====================
    echo "📏 Resize disque..."
    qm resize $VM_ID scsi0 $DISK_SIZE || echo "⚠️ Resize ignoré (déjà à la bonne taille ou erreur)"
    
    # =====================
    # CONVERT TO TEMPLATE
    # =====================
    echo "📦 Conversion en template..."
    qm template $VM_ID
    
    echo "✅ Template créé avec succès !"
    echo "👉 VM ID : $VM_ID"
    echo "👉 Nom   : $VM_NAME"
    return 0
}

# =============================================================================
# FONCTION: create_default_templates
# Description: Détecte et crée tous les templates disponibles automatiquement
# =============================================================================
create_default_templates() {
    echo "� Détection des images cloud-init disponibles..."
    echo "   Dossier de recherche : $IMAGE_SEARCH_DIR"
    echo ""
    
    local success=0
    local failed=0
    local total=0
    
    # -------------------------
    # TEMPLATE DEBIAN 13 (VM ID: 9001)
    # -------------------------
    local debian_img
    debian_img=$(find_image "debian")
    if [ -n "$debian_img" ]; then
        total=$((total + 1))
        echo "==============================="
        echo "📦 Template $total : Debian 13"
        echo "   Image : $(basename "$debian_img")"
        echo "==============================="
        if create_template \
            "9001" \
            "debian-13-cloud" \
            "$debian_img" \
            "local-lvm" \
            "vmbr0" \
            "2048" \
            "1" \
            "10G"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
            echo "⚠️  Échec création template Debian"
        fi
        echo ""
    else
        echo "⚠️  Image Debian 13 non trouvée (skip)"
    fi
    
    # -------------------------
    # TEMPLATE UBUNTU 24.04 (VM ID: 9002)
    # -------------------------
    local ubuntu24_img
    ubuntu24_img=$(find_image "ubuntu24")
    if [ -n "$ubuntu24_img" ]; then
        total=$((total + 1))
        echo "==============================="
        echo "📦 Template $total : Ubuntu 24.04"
        echo "   Image : $(basename "$ubuntu24_img")"
        echo "==============================="
        if create_template \
            "9002" \
            "ubuntu-24.04-cloud" \
            "$ubuntu24_img" \
            "local-lvm" \
            "vmbr0" \
            "2048" \
            "2" \
            "10G"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
            echo "⚠️  Échec création template Ubuntu 24.04"
        fi
        echo ""
    else
        echo "⚠️  Image Ubuntu 24.04 non trouvée (skip)"
    fi
    
    # -------------------------
    # TEMPLATE UBUNTU 26.04 (VM ID: 9003) - Optionnel
    # -------------------------
    local ubuntu26_img
    ubuntu26_img=$(find_image "ubuntu26")
    if [ -n "$ubuntu26_img" ]; then
        total=$((total + 1))
        echo "==============================="
        echo "📦 Template $total : Ubuntu 26.04"
        echo "   Image : $(basename "$ubuntu26_img")"
        echo "==============================="
        if create_template \
            "9003" \
            "ubuntu-26.04-cloud" \
            "$ubuntu26_img" \
            "local-lvm" \
            "vmbr0" \
            "2048" \
            "2" \
            "10G"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
            echo "⚠️  Échec création template Ubuntu 26.04"
        fi
        echo ""
    else
        echo "ℹ️  Image Ubuntu 26.04 non trouvée (optionnel, skip)"
    fi
    
    # Résumé final
    echo "==============================="
    echo "📊 RÉSUMÉ FINAL"
    echo "==============================="
    echo "📦 Templates trouvés : $total"
    echo "✅ Succès : $success"
    echo "❌ Échecs : $failed"
    echo "==============================="
    
    if [ "$failed" -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# =============================================================================
# MODE STANDALONE: Si exécuté directement (pas sourcé)
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Vérifier le nombre d'arguments
    if [ $# -eq 0 ]; then
        # Aucun argument → créer les templates par défaut (Debian + Ubuntu)
        echo "Aucun argument fourni → Création des templates par défaut"
        echo ""
        create_default_templates
        exit $?
    elif [ $# -lt 3 ]; then
        # Pas assez d'arguments → afficher l'aide
        echo "Usage: $0 [vm_id vm_name image_path [storage] [bridge] [memory] [cores] [disk_size]]"
        echo ""
        echo "Sans argument : crée les templates Debian (9001) et Ubuntu (9002) par défaut"
        echo ""
        echo "Avec arguments :"
        echo "  $0 9001 debian-13 /var/lib/vz/template/cloud-init-images/debian-13-generic-amd64.qcow2"
        echo "  $0 9002 ubuntu-24 /path/to/ubuntu.img local-lvm vmbr0 4096 2 20G"
        echo ""
        echo "Pour utiliser comme fonction dans un autre script:"
        echo "  source $0"
        echo "  create_template 9001 debian-13 /path/to/image.qcow2"
        exit 1
    else
        # Arguments complets → créer le template spécifié
        create_template "$@"
        exit $?
    fi
fi
