#!/bin/bash
set -euo pipefail

############################################
# CONFIGURATION
############################################
#DEST_DIR="$(pwd)/cloud-images"
# Répertoire de destination
DEST_DIR="/home/kevin-stage-devops/cloud-images"

#DEST_DIR="/var/lib/vz/template/cloud-init-images"
ISO_DIR="/var/lib/vz/template/cloud-init-images"

# Images
#DEBIAN_IMG="debian-13-genericcloud-amd64.qcow2"
DEBIAN_IMG="debian-13-generic-amd64.qcow2"
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
    
    # Vérifier wget (essentiel)
    if ! command -v wget &>/dev/null; then
        log "1.2" "wget manquant - tentative d'installation..."
        apt-get update -y || true
        apt-get install -y wget || {
            error "1.3" "Impossible d'installer wget"
            exit 1
        }
    fi
    
    # libguestfs-tools est optionnel (pour personnalisation d'images)
    if ! command -v virt-sysprep &>/dev/null; then
        warn "1.4" "libguestfs-tools non installé (optionnel)"
    fi
    
    log "1.5" "Dépendances OK"
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

    log "2.3" "Préparation du dossier $ISO_DIR..."
    
    if [ ! -d "$ISO_DIR" ]; then
        mkdir -p "$ISO_DIR"
        log "2.4" "Dossier créé"
    else
        log "2.4" "Dossier existe déjà"
    fi
}

############################################
# 3. TELECHARGEMENT DEBIAN 13
############################################
download_debian() {
    local filepath="$DEST_DIR/$DEBIAN_IMG"
    local min_size=100000000  # 100MB minimum
    
    # 1. Vérification exacte du nom
    if [ -f "$filepath" ]; then
        local filesize=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null || echo 0)
        if [ "$filesize" -gt "$min_size" ]; then
            log "3.1" "Debian 13 existe déjà (nom exact) : $DEBIAN_IMG ($(numfmt --to=iec $filesize 2>/dev/null || echo ${filesize} bytes))"
            return 0
        else
            warn "3.1" "Fichier existant trop petit ($filesize bytes) - retéléchargement..."
            rm -f "$filepath"
        fi
    fi
    
    # 2. Recherche avec pattern (debian + 13 + .qcow2)
    local found_file
    found_file=$(find "$DEST_DIR" -maxdepth 1 -type f -iname "*debian*13*.qcow2" 2>/dev/null | head -1)
    
    if [ -n "$found_file" ] && [ -f "$found_file" ]; then
        local filesize=$(stat -f%z "$found_file" 2>/dev/null || stat -c%s "$found_file" 2>/dev/null || echo 0)
        local basename=$(basename "$found_file")
        
        if [ "$filesize" -gt "$min_size" ]; then
            if [ "$basename" != "$DEBIAN_IMG" ]; then
                warn "3.2" "Image Debian 13 trouvée avec nom différent : $basename"
                warn "3.2" "Attendu : $DEBIAN_IMG - Version legacy ou variante détectée"
                log "3.2" "Utilisation de l'image existante ($(numfmt --to=iec $filesize 2>/dev/null || echo ${filesize} bytes))"
            else
                log "3.2" "Debian 13 trouvé : $basename ($(numfmt --to=iec $filesize 2>/dev/null || echo ${filesize} bytes))"
            fi
            return 0
        fi
    fi
    
    # 3. Téléchargement si aucune image trouvée
    log "3.3" "Téléchargement Debian 13..."
    wget -N -P "$DEST_DIR" "$DEBIAN_URL" || {
        error "3.4" "Échec téléchargement Debian 13"
        return 1
    }
    
    local newsize=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null || echo 0)
    log "3.5" "Debian 13 téléchargé ($(numfmt --to=iec $newsize 2>/dev/null || echo ${newsize} bytes))"
}

############################################
# 4. TELECHARGEMENT UBUNTU 24.04 (Noble Numbat)
############################################
# Idempotence avec pattern matching:
# - Vérifie nom exact: ubuntu-24.04-server-cloudimg-amd64.img
# - Sinon cherche pattern: *noble*.img OU (*ubuntu* ET *24*.img)
# - Vérifie taille minimale (100MB) pour éviter downloads incomplets
download_ubuntu_24() {
    local filepath="$DEST_DIR/$UBU24_IMG"
    local min_size=100000000  # 100MB minimum pour valider un fichier complet
    
    # ÉTAPE 1: Vérification exacte du nom de fichier
    if [ -f "$filepath" ]; then
        local filesize=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null || echo 0)
        if [ "$filesize" -gt "$min_size" ]; then
            log "4.1" "Ubuntu 24.04 existe déjà (nom exact) : $UBU24_IMG ($(numfmt --to=iec $filesize 2>/dev/null || echo ${filesize} bytes))"
            return 0
        else
            warn "4.1" "Fichier existant trop petit ($filesize bytes) - retéléchargement..."
            rm -f "$filepath"
        fi
    fi
    
    # ÉTAPE 2: Recherche avec pattern regex (fallback)
    # Pattern: (*noble*.img) OU (*ubuntu* ET *24*.img) ET finit par .img
    # noble = nom de code Ubuntu 24.04 LTS
    local found_file
    found_file=$(find "$DEST_DIR" -maxdepth 1 -type f \( -iname "*noble*.img" -o \( -iname "*ubuntu*24*.img" \) \) 2>/dev/null | head -1)
    
    if [ -n "$found_file" ] && [ -f "$found_file" ]; then
        local filesize=$(stat -f%z "$found_file" 2>/dev/null || stat -c%s "$found_file" 2>/dev/null || echo 0)
        local basename=$(basename "$found_file")
        
        if [ "$filesize" -gt "$min_size" ]; then
            if [ "$basename" != "$UBU24_IMG" ]; then
                warn "4.2" "Image Ubuntu 24.04 trouvée avec nom différent : $basename"
                warn "4.2" "Attendu : $UBU24_IMG - Détection via pattern (*noble*.img ou *ubuntu*24*.img)"
                log "4.2" "Utilisation de l'image existante ($(numfmt --to=iec $filesize 2>/dev/null || echo ${filesize} bytes))"
            else
                log "4.2" "Ubuntu 24.04 trouvé : $basename ($(numfmt --to=iec $filesize 2>/dev/null || echo ${filesize} bytes))"
            fi
            return 0
        fi
    fi
    
    # ÉTAPE 3: Téléchargement si aucune image trouvée
    log "4.3" "Téléchargement Ubuntu 24.04 LTS..."
    wget -N -P "$DEST_DIR" "$UBU24_URL" || {
        error "4.4" "Échec téléchargement Ubuntu 24.04"
        return 1
    }
    
    local newsize=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null || echo 0)
    log "4.5" "Ubuntu 24.04 téléchargé ($(numfmt --to=iec $newsize 2>/dev/null || echo ${newsize} bytes))"
}

############################################
# 5. TELECHARGEMENT UBUNTU 26.04 (Resolute Raccoon - Daily)
############################################
# Idempotence avec pattern matching:
# - Vérifie nom exact: ubuntu-26.04-server-cloudimg-amd64.img
# - Sinon cherche pattern: *resolute*.img OU (*ubuntu* ET *26*.img)
# - resolute = nom de code Ubuntu 26.04
# - Vérifie taille minimale (100MB) pour éviter downloads incomplets
download_ubuntu_26() {
    local filepath="$DEST_DIR/$UBU26_IMG"
    local min_size=100000000  # 100MB minimum pour valider un fichier complet
    
    # ÉTAPE 1: Vérification exacte du nom de fichier
    if [ -f "$filepath" ]; then
        local filesize=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null || echo 0)
        if [ "$filesize" -gt "$min_size" ]; then
            log "5.1" "Ubuntu 26.04 existe déjà (nom exact) : $UBU26_IMG ($(numfmt --to=iec $filesize 2>/dev/null || echo ${filesize} bytes))"
            return 0
        else
            warn "5.1" "Fichier existant trop petit ($filesize bytes) - retéléchargement..."
            rm -f "$filepath"
        fi
    fi
    
    # ÉTAPE 2: Recherche avec pattern regex (fallback)
    # Pattern: (*resolute*.img) OU (*ubuntu* ET *26*.img) ET finit par .img
    # resolute = nom de code Ubuntu 26.04 LTS (daily builds)
    local found_file
    found_file=$(find "$DEST_DIR" -maxdepth 1 -type f \( -iname "*resolute*.img" -o \( -iname "*ubuntu*26*.img" \) \) 2>/dev/null | head -1)
    
    if [ -n "$found_file" ] && [ -f "$found_file" ]; then
        local filesize=$(stat -f%z "$found_file" 2>/dev/null || stat -c%s "$found_file" 2>/dev/null || echo 0)
        local basename=$(basename "$found_file")
        
        if [ "$filesize" -gt "$min_size" ]; then
            if [ "$basename" != "$UBU26_IMG" ]; then
                warn "5.2" "Image Ubuntu 26.04 trouvée avec nom différent : $basename"
                warn "5.2" "Attendu : $UBU26_IMG - Détection via pattern (*resolute*.img ou *ubuntu*26*.img)"
                log "5.2" "Utilisation de l'image existante ($(numfmt --to=iec $filesize 2>/dev/null || echo ${filesize} bytes))"
            else
                log "5.2" "Ubuntu 26.04 trouvé : $basename ($(numfmt --to=iec $filesize 2>/dev/null || echo ${filesize} bytes))"
            fi
            return 0
        fi
    fi
    
    # ÉTAPE 3: Téléchargement si aucune image trouvée
    # Note: Les daily builds peuvent être temporairement indisponibles
    log "5.3" "Téléchargement Ubuntu 26.04 (Daily)..."
    wget -N -P "$DEST_DIR" "$UBU26_URL" || {
        warn "5.4" "Échec téléchargement Ubuntu 26.04 (daily peut être indisponible)"
        return 1
    }
    
    local newsize=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null || echo 0)
    log "5.5" "Ubuntu 26.04 téléchargé ($(numfmt --to=iec $newsize 2>/dev/null || echo ${newsize} bytes))"
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
    echo "=== Vérification des fichiers ==="
    ls -lh "$DEST_DIR" 2>/dev/null || true




    echo "=== Copie vers le dossier ISO si nécessaire ==="
    cp -n "$DEST_DIR"/*.img "$ISO_DIR" 2>/dev/null || true
    cp -n "$DEST_DIR"/*.qcow2 "$ISO_DIR" 2>/dev/null || true
}

main "$@"
