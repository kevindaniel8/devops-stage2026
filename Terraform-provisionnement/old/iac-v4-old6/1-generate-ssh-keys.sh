#!/bin/bash
set -e

##############################################
# CONFIGURATION GLOBALE
##############################################

SSH_DIR="./ssh"
KEY_NAME="id_ed25519_terraform-proxmox"
KEY_TYPE="ed25519"
KEY_BITS=""
GITHUB_REPO_NAME="devops-stage2026"

PRIVATE_KEY="$SSH_DIR/$KEY_NAME"
PUBLIC_KEY="$SSH_DIR/$KEY_NAME.pub"
TERRAFORM_SSH_FILE="$SSH_DIR/terraform-ssh-config.txt"
GITHUB_ACTIONS_FILE="$SSH_DIR/github-actions-example.yml"

##############################################
# 1. CRÉATION DU RÉPERTOIRE SSH
##############################################
create_ssh_directory() {
    echo "1️⃣  Création du répertoire SSH si nécessaire..."
    if [ ! -d "$SSH_DIR" ]; then
        mkdir -p "$SSH_DIR"
        echo "   ➜ Répertoire créé : $SSH_DIR"
    fi
}

##############################################
# 2. RÉGÉNÉRATION DES CLÉS SSH
##############################################
generate_ssh_keys() {
    echo "2️⃣  Régénération des clés SSH..."

    # Suppression des anciennes clés
    if [ -f "$PRIVATE_KEY" ] || [ -f "$PUBLIC_KEY" ]; then
        echo "   ➜ Suppression des anciennes clés..."
        rm -f "$PRIVATE_KEY" "$PUBLIC_KEY"
    fi

    # Génération
    echo "   ➜ Génération de la paire de clés ($KEY_TYPE)"
    if [ -n "$KEY_BITS" ]; then
        ssh-keygen -t "$KEY_TYPE" -b "$KEY_BITS" -f "$PRIVATE_KEY" -N "" -C "terraform-proxmox-key"
    else
        ssh-keygen -t "$KEY_TYPE" -f "$PRIVATE_KEY" -N "" -C "terraform-proxmox-key"
    fi

    # Permissions
    chmod 700 "$SSH_DIR"
    chmod 600 "$PRIVATE_KEY"
    chmod 644 "$PUBLIC_KEY"

    echo "   ✔️ Clés générées :"
    echo "      - Privée : $PRIVATE_KEY"
    echo "      - Publique : $PUBLIC_KEY"
}

##############################################
# 3. SYNCHRONISATION DES CLÉS VERS ~/.ssh/
##############################################
sync_ssh_keys_to_user() {
    echo "3️⃣  Synchronisation des clés vers ~/.ssh..."

    USER_SSH_DIR="$HOME/.ssh"
    USER_PRIVATE_KEY="$USER_SSH_DIR/$KEY_NAME"
    USER_PUBLIC_KEY="$USER_SSH_DIR/$KEY_NAME.pub"
    BACKUP_DIR="$USER_SSH_DIR/backup"

    mkdir -p "$USER_SSH_DIR"
    chmod 700 "$USER_SSH_DIR"

    ##############################################
    # 3.1 Sauvegarde des anciennes clés (création .bak)
    ##############################################
    if [ -f "$USER_PRIVATE_KEY" ] || [ -f "$USER_PUBLIC_KEY" ]; then
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        echo "   ⚠️  Clés existantes détectées → création de fichiers .bak"

        [ -f "$USER_PRIVATE_KEY" ] && cp "$USER_PRIVATE_KEY" "$USER_PRIVATE_KEY.$TIMESTAMP.bak"
        [ -f "$USER_PUBLIC_KEY" ] && cp "$USER_PUBLIC_KEY" "$USER_PUBLIC_KEY.$TIMESTAMP.bak"

        rm -f "$USER_PRIVATE_KEY" "$USER_PUBLIC_KEY"
    fi

    ##############################################
    # 3.2 Déplacement des .bak dans ~/.ssh/backup/
    ##############################################
    BAK_FILES=$(find "$USER_SSH_DIR" -maxdepth 1 -type f -name "*.bak")

    if [ -n "$BAK_FILES" ]; then
        echo "   📦 Déplacement des fichiers .bak vers ~/.ssh/backup/"

        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"

        while IFS= read -r bak; do
            mv "$bak" "$BACKUP_DIR/"
            echo "   ➜ Déplacé : $(basename "$bak")"
        done <<< "$BAK_FILES"
    fi

    ##############################################
    # 3.3 Copie des nouvelles clés
    ##############################################
    cp "$PRIVATE_KEY" "$USER_PRIVATE_KEY"
    cp "$PUBLIC_KEY" "$USER_PUBLIC_KEY"

    chmod 600 "$USER_PRIVATE_KEY"
    chmod 644 "$USER_PUBLIC_KEY"

    echo "   ✔️ Nouvelles clés synchronisées dans ~/.ssh/"
}


##############################################
# 4. COPIE AUTOMATIQUE DANS LE PRESSE-PAPIERS
##############################################
copy_public_key_to_clipboard() {
    echo "4️⃣  Copie de la clé publique dans le presse-papiers (si possible)..."

    if command -v pbcopy >/dev/null 2>&1; then
        cat "$PUBLIC_KEY" | pbcopy
        echo "   ➜ Copié (macOS)"
    elif command -v xclip >/dev/null 2>&1; then
        cat "$PUBLIC_KEY" | xclip -selection clipboard
        echo "   ➜ Copié (Linux)"
    elif command -v clip.exe >/dev/null 2>&1; then
        cat "$PUBLIC_KEY" | clip.exe
        echo "   ➜ Copié (WSL/Windows)"
    else
        echo "   ❌ Aucun outil de copie détecté"
    fi
}

##############################################
# 5. GÉNÉRATION DU FICHIER TERRAFORM
##############################################
generate_terraform_config() {
    echo "5️⃣  Génération du fichier Terraform..."

    cat > "$TERRAFORM_SSH_FILE" << EOF
# Configuration SSH pour Terraform
# Généré le $(date)

ssh_public_key = "$(cat $PUBLIC_KEY)"
private_key_path = "./ssh/$KEY_NAME"
ssh_user = "ubuntu"
EOF

    chmod 600 "$TERRAFORM_SSH_FILE"
    echo "   ✔️ Fichier créé : $TERRAFORM_SSH_FILE"
}

##############################################
# 6. GÉNÉRATION DU WORKFLOW GITHUB ACTIONS
##############################################
generate_github_actions_example() {
    echo "6️⃣  Génération du workflow GitHub Actions..."

    cat > "$GITHUB_ACTIONS_FILE" << EOF
# Exemple de workflow GitHub Actions pour Terraform

name: 'Terraform Proxmox'

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  terraform:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: '1.5.0'

    - name: Configure SSH Key
      run: |
        mkdir -p ~/.ssh
        echo "\${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
        chmod 600 ~/.ssh/id_rsa
        ssh-keyscan -H \${{ secrets.PROXMOX_HOST }} >> ~/.ssh/known_hosts

    - name: Terraform Init
      run: terraform init
      env:
        TF_VAR_pm_host: \${{ secrets.PROXMOX_HOST }}
        TF_VAR_pm_token_id: \${{ secrets.PROXMOX_TOKEN_ID }}
        TF_VAR_pm_token_secret: \${{ secrets.PROXMOX_TOKEN_SECRET }}
        TF_VAR_ssh_public_key: "$(cat $PUBLIC_KEY)"

    - name: Terraform Plan
      run: terraform plan
      env:
        TF_VAR_pm_host: \${{ secrets.PROXMOX_HOST }}
        TF_VAR_pm_token_id: \${{ secrets.PROXMOX_TOKEN_ID }}
        TF_VAR_pm_token_secret: \${{ secrets.PROXMOX_TOKEN_SECRET }}
        TF_VAR_ssh_public_key: "$(cat $PUBLIC_KEY)"

    - name: Terraform Apply
      if: github.ref == 'refs/heads/main'
      run: terraform apply -auto-approve
      env:
        TF_VAR_pm_host: \${{ secrets.PROXMOX_HOST }}
        TF_VAR_pm_token_id: \${{ secrets.PROXMOX_TOKEN_ID }}
        TF_VAR_pm_token_secret: \${{ secrets.PROXMOX_TOKEN_SECRET }}
        TF_VAR_ssh_public_key: "$(cat $PUBLIC_KEY)"
EOF

    chmod 644 "$GITHUB_ACTIONS_FILE"
    echo "   ✔️ Fichier créé : $GITHUB_ACTIONS_FILE"
}

##############################################
# 7. AFFICHAGE DES INFORMATIONS
##############################################
display_summary() {
    echo ""
    echo "7️⃣  Résumé :"
    echo "----------------------------------------"
    echo "Clé publique :"
    cat "$PUBLIC_KEY"
    echo "----------------------------------------"
    echo ""
    echo "Clé privée (Terraform) :"
    echo "----------------------------------------"
    cat "$PRIVATE_KEY"
    echo "----------------------------------------"
}

##############################################
# MAIN — ORCHESTRATION
##############################################
main() {
    echo "=== Génération complète des clés SSH Terraform/Proxmox ==="

    create_ssh_directory
    generate_ssh_keys
    sync_ssh_keys_to_user
    copy_public_key_to_clipboard
    generate_terraform_config
    generate_github_actions_example
    display_summary

    echo ""
    echo "🎉 Configuration SSH terminée !"
}

main
