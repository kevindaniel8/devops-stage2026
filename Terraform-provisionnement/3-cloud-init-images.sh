#!/bin/bash
set -euo pipefail

############################################
# CONFIGURATION
############################################
#DEST_DIR="$(pwd)/cloud-images"
# Répertoire de destination
DEST_DIR="/home/kevin-stage-devops/cloud-images"

# Images
DEBIAN_IMG="debian-13-genericcloud-amd64.qcow2"
DEBIAN_URL="https://cloud.debian.org/images/cloud/trixie/latest/$DEBIAN_IMG"

UBU24_IMG="ubuntu-24.04-server-cloudimg-amd64.img"
UBU24_URL="https://cloud-images.ubuntu.com/noble/current/$UBU24_IMG"

UBU26_IMG="ubuntu-26.04-server-cloudimg-amd64.img"
UBU26_URL="https://cloud-images.ubuntu.com/daily/server/$UBU26_IMG"

############################################
# 1. VERIFICATION DEPENDANCES
############################################
check_dependencies() {
    log "1.1" "Vérification des dépendances..."
    
    local missing=()
    
    if ! command -v wget &>/dev/null; then
        missing+=("wget")
    fi
    
    if ! command -v virt-sysprep &>/dev/null; then
        missing+=("libguestfs-tools")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log "1.2" "Installation des packages manquants: ${missing[*]}"
        apt-get update -y
        apt-get install -y "${missing[@]}"
    fi
    
    log "1.3" "Dépendances OK"
}

############################################
# 2. CREATION DOSSIER
############################################
create_directory() {
    log "2.1" "Préparation du dossier $DEST_DIR..."
    
    if [ ! -d "$DEST_DIR" ]; then
        mkdir -p "$DEST_DIR"
        log "2.2" "Dossier créé"
    else
        log "2.2" "Dossier existe déjà"
    fi
}

############################################
# 3. TELECHARGEMENT DEBIAN 13
############################################
download_debian() {
    local filepath="$DEST_DIR/$DEBIAN_IMG"
    
    if [ -f "$filepath" ]; then
        log "3.1" "Debian 13 existe déjà ($filepath)"
        return 0
    fi
    
    log "3.1" "Téléchargement Debian 13..."
    wget -N -P "$DEST_DIR" "$DEBIAN_URL" || {
        error "3.2" "Échec téléchargement Debian 13"
        return 1
    }
    log "3.3" "Debian 13 téléchargé"
}

############################################
# 4. TELECHARGEMENT UBUNTU 24.04
############################################
download_ubuntu_24() {
    local filepath="$DEST_DIR/$UBU24_IMG"
    
    if [ -f "$filepath" ]; then
        log "4.1" "Ubuntu 24.04 existe déjà ($filepath)"
        return 0
    fi
    
    log "4.1" "Téléchargement Ubuntu 24.04 LTS..."
    wget -N -P "$DEST_DIR" "$UBU24_URL" || {
        error "4.2" "Échec téléchargement Ubuntu 24.04"
        return 1
    }
    log "4.3" "Ubuntu 24.04 téléchargé"
}

############################################
# 5. TELECHARGEMENT UBUNTU 26.04
############################################
download_ubuntu_26() {
    local filepath="$DEST_DIR/$UBU26_IMG"
    
    if [ -f "$filepath" ]; then
        log "5.1" "Ubuntu 26.04 existe déjà ($filepath)"
        return 0
    fi
    
    log "5.1" "Téléchargement Ubuntu 26.04 (Daily)..."
    wget -N -P "$DEST_DIR" "$UBU26_URL" || {
        warn "5.2" "Échec téléchargement Ubuntu 26.04 (daily peut être indisponible)"
        return 1
    }
    log "5.3" "Ubuntu 26.04 téléchargé"
}

############################################
# LOGGING
############################################
log() { echo -e "\033[1;32m[INFO $1]\033[0m ${2}" >&2; }
warn() { echo -e "\033[1;33m[WARN $1]\033[0m ${2}" >&2; }
error() { echo -e "\033[1;31m[ERROR $1]\033[0m ${2}" >&2; }

############################################
# MAIN - ORCHESTRATION
############################################
main() {
    local target="${1:-all}"
    
    echo "=== Téléchargement Images Cloud-Init ==="
    echo "Mode: $target"
    echo ""
    
    # Étape 1: Dépendances
    check_dependencies
    
    # Étape 2: Dossier
    create_directory
    
    # Étape 3+: Téléchargements selon paramètre
    case "$target" in
        debian|debian13)
            download_debian
            ;;
        24.04|ubuntu24|noble)
            download_ubuntu_24
            ;;
        26.04|ubuntu26|daily)
            download_ubuntu_26
            ;;
        all|"")
            download_debian
            download_ubuntu_24
            download_ubuntu_26
            ;;
        *)
            error "0" "Paramètre inconnu: $target"
            echo "Usage: $0 [debian|24.04|26.04|all]"
            exit 1
            ;;
    esac
    
    echo ""
    log "6.1" "Téléchargement terminé"
    log "6.2" "Images dans: $DEST_DIR"
    ls -lh "$DEST_DIR" 2>/dev/null || true
}

main "$@"
