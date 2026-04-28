#!/bin/bash
set -e

# Configuration
SSH_DIR="./ssh"
KEY_NAME="id_ed25519_terraform-proxmox"
KEY_TYPE="ed25519"
KEY_BITS=""
GITHUB_REPO_NAME="devops-stage2026"  # À adapter selon votre repo

echo "=== Génération des clés SSH sécurisées pour Terraform/Proxmox + GitHub ==="

# Créer le répertoire SSH s'il n'existe pas
if [ ! -d "$SSH_DIR" ]; then
    echo "Création du répertoire SSH: $SSH_DIR"
    mkdir -p "$SSH_DIR"
fi

# Vérifier si les clés existent déjà et les supprimer systématiquement
PRIVATE_KEY="$SSH_DIR/${KEY_NAME}"
PUBLIC_KEY="$SSH_DIR/${KEY_NAME}.pub"

echo "🔄 Régénération systématique des clés SSH..."
if [ -f "$PRIVATE_KEY" ] || [ -f "$PUBLIC_KEY" ]; then
    echo "Suppression des anciennes clés locales..."
    rm -f "$PRIVATE_KEY" "$PUBLIC_KEY"
fi

# Générer la paire de clés SSH
echo "Génération de la paire de clés SSH ($KEY_TYPE)..."
if [ -n "$KEY_BITS" ]; then
    ssh-keygen -t "$KEY_TYPE" -b "$KEY_BITS" -f "$PRIVATE_KEY" -N "" -C "terraform-proxmox-key"
else
    ssh-keygen -t "$KEY_TYPE" -f "$PRIVATE_KEY" -N "" -C "terraform-proxmox-key"
fi

# Définir les permissions sécurisées
echo "Configuration des permissions sécurisées..."
chmod 700 "$SSH_DIR"
chmod 600 "$PRIVATE_KEY"
chmod 644 "$PUBLIC_KEY"

# Fonction pour synchroniser les clés de ./ssh/ vers ~/.ssh/
sync_ssh_keys_to_user() {
    USER_SSH_DIR="$HOME/.ssh"
    USER_PRIVATE_KEY="$USER_SSH_DIR/$KEY_NAME"
    USER_PUBLIC_KEY="$USER_SSH_DIR/$KEY_NAME.pub"
    
    echo "📁 Synchronisation des clés vers ~/.ssh de l'utilisateur..."
    
    # Créer le répertoire ~/.ssh s'il n'existe pas
    if [ ! -d "$USER_SSH_DIR" ]; then
        echo "Création du répertoire ~/.ssh..."
        mkdir -p "$USER_SSH_DIR"
        chmod 700 "$USER_SSH_DIR"
    fi
    
    # Vérifier si les clés locales existent
    if [ ! -f "$PRIVATE_KEY" ] || [ ! -f "$PUBLIC_KEY" ]; then
        echo "❌ Erreur: Les clés locales n'existent pas dans $SSH_DIR/"
        exit 1
    fi
    
    # Vérifier si des clés existent dans ~/.ssh et faire un backup
    if [ -f "$USER_PRIVATE_KEY" ] || [ -f "$USER_PUBLIC_KEY" ]; then
        echo "⚠️  Clés existantes trouvées dans ~/.ssh"
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        BACKUP_PRIVATE="$USER_PRIVATE_KEY.$TIMESTAMP.backup"
        BACKUP_PUBLIC="$USER_PUBLIC_KEY.$TIMESTAMP.backup"
        
        echo "📦 Sauvegarde des anciennes clés..."
        if [ -f "$USER_PRIVATE_KEY" ]; then
            cp "$USER_PRIVATE_KEY" "$BACKUP_PRIVATE"
            echo "   Clé privée sauvegardée: $BACKUP_PRIVATE"
        fi
        if [ -f "$USER_PUBLIC_KEY" ]; then
            cp "$USER_PUBLIC_KEY" "$BACKUP_PUBLIC"
            echo "   Clé publique sauvegardée: $BACKUP_PUBLIC"
        fi
        
        # Supprimer les anciennes clés
        rm -f "$USER_PRIVATE_KEY" "$USER_PUBLIC_KEY"
        echo "🗑️  Anciennes clés supprimées de ~/.ssh"
    fi
    
    # Copier les nouvelles clés dans ~/.ssh (depuis ./ssh/)
    echo "📋 Synchronisation des clés de ./ssh/ vers ~/.ssh..."
    cp "$PRIVATE_KEY" "$USER_PRIVATE_KEY"
    cp "$PUBLIC_KEY" "$USER_PUBLIC_KEY"
    
    # Définir les permissions correctes
    chmod 600 "$USER_PRIVATE_KEY"
    chmod 644 "$USER_PUBLIC_KEY"
    
    echo "✅ Clés synchronisées dans ~/.ssh"
    echo "   Source: $PRIVATE_KEY → $USER_PRIVATE_KEY"
    echo "   Source: $PUBLIC_KEY → $USER_PUBLIC_KEY"
}

# Synchroniser les clés de ./ssh/ vers ~/.ssh/
sync_ssh_keys_to_user

# Afficher les informations
echo ""
echo "✅ Clés SSH générées avec succès !"
echo ""
echo "📁 Emplacement des clés :"
echo "   Clé privée : $PRIVATE_KEY"
echo "   Clé publique : $PUBLIC_KEY"
echo ""

# Afficher la clé publique pour copie
echo "🔑 Clé publique (à ajouter dans GitHub et Terraform) :"
echo "--------------------------------------------------------"
cat "$PUBLIC_KEY"
echo "--------------------------------------------------------"
echo ""

# Copier la clé publique dans le presse-papiers si possible
if command -v pbcopy >/dev/null 2>&1; then
    cat "$PUBLIC_KEY" | pbcopy
    echo "📋 Clé publique copiée dans le presse-papiers (macOS)"
elif command -v xclip >/dev/null 2>&1; then
    cat "$PUBLIC_KEY" | xclip -selection clipboard
    echo "📋 Clé publique copiée dans le presse-papiers (Linux)"
elif command -v clip.exe >/dev/null 2>&1; then
    cat "$PUBLIC_KEY" | clip.exe
    echo "📋 Clé publique copiée dans le presse-papiers (WSL/Windows)"
fi

# Afficher la clé privée pour Terraform
echo "🔒 Clé privée (pour Terraform) :"
echo "--------------------------------------------------------"
cat "$PRIVATE_KEY"
echo "--------------------------------------------------------"
echo ""

# Créer un fichier de configuration pour Terraform
TERRAFORM_SSH_FILE="$SSH_DIR/terraform-ssh-config.txt"
cat > "$TERRAFORM_SSH_FILE" << EOF
# Configuration SSH pour Terraform
# Généré le $(date)
# Source de vérité: ./ssh/ (répertoire local du projet)

# Clé publique à utiliser dans :
# - GitHub (SSH keys)
# - Terraform (variable ssh_public_key)
# - Cloud-Init des VM
# Source: ./ssh/id_ed25519_terraform-proxmox.pub

ssh_public_key = "$(cat $PUBLIC_KEY)"

# Chemin de la clé privée pour les connexions SSH (lien relatif)
# Source: ./ssh/id_ed25519_terraform-proxmox
private_key_path = "./ssh/id_ed25519_terraform-proxmox"

# Utilisateur SSH par défaut
ssh_user = "ubuntu"

# Note: Les clés sont également synchronisées dans ~/.ssh/ pour l'accès système
EOF

chmod 600 "$TERRAFORM_SSH_FILE"

echo "📋 Fichier de configuration Terraform créé : $TERRAFORM_SSH_FILE"
echo ""

# Instructions pour GitHub
echo "🐙 Instructions pour GitHub :"
echo "1. Copiez la clé publique ci-dessus"
echo "2. Allez dans GitHub > Settings > SSH and GPG keys"
echo "3. Cliquez sur 'New SSH key'"
echo "4. Collez la clé publique et donnez-lui un nom (ex: 'terraform-proxmox')"
echo ""
echo "🤖 Pour GitHub Actions :"
echo "1. Allez dans votre repository > Settings > Secrets and variables > Actions"
echo "2. Ajoutez ces secrets :"
echo "   - SSH_PRIVATE_KEY: (collez la clé privée ci-dessus)"
echo "   - PROXMOX_HOST: (adresse IP de votre Proxmox)"
echo "   - PROXMOX_TOKEN_ID: (token ID généré par le script 2-create-user-proxmox.sh)"
echo "   - PROXMOX_TOKEN_SECRET: (token secret généré par le script 2-create-user-proxmox.sh)"
echo ""
echo "🏃 Pour GitHub Runner :"
echo "1. Le runner utilisera la clé SSH pour se connecter aux VM créées"
echo "2. Assurez-vous que la clé publique est ajoutée dans Cloud-Init des VM"
echo "3. Le runner peut exécuter des commandes sur les VM via SSH"
echo ""

# Instructions pour Terraform
echo "🏗️  Instructions pour Terraform :"
echo "1. Copiez la clé publique dans votre variable ssh_public_key"
echo "2. Utilisez la clé privée pour les connexions aux VM"
echo "3. Ajoutez la clé publique dans Cloud-Init des VM"
echo ""

# Créer un fichier GitHub Actions example
GITHUB_ACTIONS_FILE="$SSH_DIR/github-actions-example.yml"
cat > "$GITHUB_ACTIONS_FILE" << EOF
# Exemple de workflow GitHub Actions pour Terraform
# Placez ce fichier dans .github/workflows/terraform.yml

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
    - name: Checkout repository
      uses: actions/checkout@v3
      
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
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
      run: terraform apply -auto-approve
      env:
        TF_VAR_pm_host: \${{ secrets.PROXMOX_HOST }}
        TF_VAR_pm_token_id: \${{ secrets.PROXMOX_TOKEN_ID }}
        TF_VAR_pm_token_secret: \${{ secrets.PROXMOX_TOKEN_SECRET }}
        TF_VAR_ssh_public_key: "$(cat $PUBLIC_KEY)"
      if: github.ref == 'refs/heads/main'
EOF

chmod 644 "$GITHUB_ACTIONS_FILE"
echo "📄 Fichier GitHub Actions example créé : $GITHUB_ACTIONS_FILE"
echo ""

# Instructions de sécurité
echo "🔐 Instructions de sécurité :"
echo "- Ne partagez jamais la clé privée"
echo "- La clé privée est protégée par les permissions 600"
echo "- Stockez la clé privée dans un gestionnaire de mots de passe"
echo "- Utilisez des clés différentes pour différents environnements"
echo ""

# Test de la clé
echo "🧪 Test de la clé SSH..."
echo "Vous pouvez tester la clé avec :"
echo "ssh -i $PRIVATE_KEY -T git@github.com"
echo ""

echo "🎉 Configuration SSH terminée !"
echo "Les clés sont prêtes à être utilisées avec Terraform et GitHub."
