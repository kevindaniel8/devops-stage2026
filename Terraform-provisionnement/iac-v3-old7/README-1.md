# 1-generate-ssh-keys.sh - Génération de clés SSH pour Terraform/Proxmox + GitHub

Ce script génère des clés SSH sécurisées (ED25519) pour l'intégration complète entre Terraform, Proxmox et GitHub Actions.

## 🚀 Fonctionnalités

- **Génération de clés SSH** : Crée une paire de clés ED25519 sécurisées
- **Structure modulaire** : 7 fonctions indépendantes et réutilisables
- **Backup automatique** : Sauvegarde et archive les anciennes clés
- **Copie automatique** : Copie la clé publique dans le presse-papiers (macOS/Linux/WSL)
- **Configuration Terraform** : Génère le fichier `terraform-ssh-config.txt`
- **Workflow GitHub Actions** : Crée un exemple de workflow CI/CD
- **Sécurité** : Permissions strictes (600/644) pour les fichiers SSH

## 📋 Prérequis

- Système d'exploitation : macOS, Linux ou WSL/Windows
- `ssh-keygen` installé (inclus avec OpenSSH)
- Accès à un repository GitHub (optionnel)

## 🛠️ Utilisation

### Exécution du script

```bash
# Rendre le script exécutable
chmod +x 1-generate-ssh-keys.sh

# Exécuter le script
./1-generate-ssh-keys.sh
```

### Comportement

Le script **régénère systématiquement** les clés à chaque exécution :
- Suppression des anciennes clés locales (`./ssh/`)
- Génération d'une nouvelle paire ED25519
- Backup automatique des clés existantes dans `~/.ssh/backup/`
- Synchronisation des nouvelles clés dans `~/.ssh/`

## 📁 Fichiers générés

Le script crée les fichiers suivants dans **deux emplacements** :

### **1. Répertoire local `./ssh/` (projet)**
```
ssh/
├── id_ed25519_terraform-proxmox          # Clé privée (permissions 600)
├── id_ed25519_terraform-proxmox.pub      # Clé publique (permissions 644)
├── terraform-ssh-config.txt              # Configuration Terraform
└── github-actions-example.yml            # Workflow GitHub Actions
```

### **2. Répertoire utilisateur `~/.ssh/` (système)**
```
~/.ssh/
├── id_ed25519_terraform-proxmox              # Clé privée (permissions 600)
├── id_ed25519_terraform-proxmox.pub          # Clé publique (permissions 644)
└── backup/
    └── id_ed25519_terraform-proxmox.*.bak    # Anciennes clés archivées
```

## 🔧 Structure du code (7 fonctions)

| Fonction | Description |
|----------|-------------|
| `create_ssh_directory()` | Crée le répertoire `./ssh/` si inexistant |
| `generate_ssh_keys()` | Génère la paire ED25519 avec permissions |
| `sync_ssh_keys_to_user()` | Backup dans `~/.ssh/backup/` + sync |
| `copy_public_key_to_clipboard()` | Copie la clé publique (macOS/Linux/WSL) |
| `generate_terraform_config()` | Crée `terraform-ssh-config.txt` |
| `generate_github_actions_example()` | Crée `github-actions-example.yml` |
| `display_summary()` | Affiche les clés générées |

## 🔄 Gestion des clés

### **Régénération automatique**
Le script régénère **systématiquement** les clés à chaque exécution :
- Supprime les anciennes clés locales (`./ssh/`)
- Génère une nouvelle paire de clés ED25519
- Copie les nouvelles clés dans `~/.ssh/`

### **Backup automatique (3 étapes)**

Si des clés existent déjà dans `~/.ssh/` :

1. **3.1 - Création .bak** : Sauvegarde avec timestamp (`.bak`)
2. **3.2 - Archivage** : Déplacement des `.bak` vers `~/.ssh/backup/`
3. **3.3 - Sync** : Copie des nouvelles clés dans `~/.ssh/`

### **Flux des clés**

```
Génération (./ssh/) ──▶ Backup (~/.ssh/backup/) ──▶ Sync (~/.ssh/)
       │                         │                      │
       │                         ▼                      ▼
       │              id_ed25519_terraform-proxmox.*.bak
       ▼
  Clés fraîches ────────────────────────────────────────▶
```

## 🔑 Configuration GitHub

### 1. Ajouter la clé SSH à GitHub

1. Copiez la clé publique affichée par le script
2. Allez dans **GitHub > Settings > SSH and GPG keys**
3. Cliquez sur **New SSH key**
4. Donnez un nom (ex: `terraform-proxmox`)
5. Collez la clé publique

### 2. Configurer les secrets GitHub Actions

Dans votre repository GitHub, allez dans **Settings > Secrets and variables > Actions** et ajoutez :

| Secret | Valeur |
|--------|--------|
| `SSH_PRIVATE_KEY` | Clé privée générée par le script |
| `PROXMOX_HOST` | Adresse IP de votre serveur Proxmox |
| `PROXMOX_TOKEN_ID` | Token ID (généré par `2-create-user-proxmox.sh`) |
| `PROXMOX_TOKEN_SECRET` | Token secret (généré par `2-create-user-proxmox.sh`) |

### 3. Configurer le workflow GitHub Actions

1. Copiez le fichier `ssh/github-actions-example.yml`
2. Placez-le dans `.github/workflows/terraform.yml`
3. Adaptez-le selon vos besoins

## 🏗️ Intégration Terraform

### Utilisation des clés dans Terraform

Dans votre fichier `terraform.tfvars` :

```hcl
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA..."  # Clé publique générée
```

### Configuration Cloud-Init

La clé publique sera automatiquement ajoutée aux VM créées par Terraform pour permettre les connexions SSH.

## 🏃 GitHub Runner

Le GitHub Runner utilisera la clé SSH pour :

- Se connecter aux VM créées par Terraform
- Exécuter des commandes sur les VM
- Déployer des applications
- Effectuer des tests et validations

## 🔐 Sécurité

### Permissions des fichiers

- **Dossier `ssh/`** : 700 (lecture/écriture/exécution pour le propriétaire)
- **Clé privée** : 600 (lecture/écriture pour le propriétaire uniquement)
- **Clé publique** : 644 (lecture pour tous, écriture pour le propriétaire)

### Bonnes pratiques

- **Ne jamais partager la clé privée**
- **Utiliser des clés différentes** pour chaque environnement
- **Stockez la clé privée** dans un gestionnaire de mots de passe
- **Faites rotation des clés** régulièrement
- **Utilisez des secrets GitHub** pour stocker les informations sensibles

## 🧪 Tests et validation

### Test de la clé SSH

```bash
# Test de connexion à GitHub
ssh -i ./ssh/id_ed25519_terraform-proxmox -T git@github.com

# Test de connexion à une VM (après déploiement Terraform)
ssh -i ./ssh/id_ed25519_terraform-proxmox ubuntu@<IP_VM>
```

### Validation du workflow

1. Poussez le workflow dans votre repository
2. Vérifiez l'exécution dans l'onglet **Actions** de GitHub
3. Confirmez que Terraform s'exécute correctement

## 📋 Commandes utiles

```bash
# Vérifier les permissions
ls -la ./ssh/

# Afficher la clé publique
cat ./ssh/id_ed25519_terraform-proxmox.pub

# Afficher la clé privée
cat ./ssh/id_ed25519_terraform-proxmox

# Test de connexion SSH
ssh -i ./ssh/id_ed25519_terraform-proxmox -T git@github.com

# Regénérer les clés
./1-connection-secure-ssh.sh
```

## 🚨 Dépannage

### Erreurs courantes

| Erreur | Solution |
|--------|----------|
| `Permission denied` | Vérifiez les permissions des fichiers SSH |
| `Could not open a connection` | Vérifiez votre connexion internet et la configuration SSH |
| `Invalid key format` | Regénérez les clés avec le script |
| `GitHub secrets not found` | Ajoutez les secrets requis dans Settings > Secrets |

### Debug

```bash
# Mode debug SSH
ssh -vvv -i ./ssh/terraform-proxmox -T git@github.com

# Vérifier la configuration Terraform
terraform validate

# Vérifier l'état Terraform
terraform state list
```

## 🔄 Maintenance

### Rotation des clés

Pour regénérer les clés :

1. Exécutez à nouveau le script : `./1-connection-secure-ssh.sh`
2. Mettez à jour la clé publique dans GitHub
3. Mettez à jour le secret `SSH_PRIVATE_KEY` dans GitHub Actions
4. Mettez à jour la variable `ssh_public_key` dans Terraform

### Nettoyage

Pour supprimer toutes les clés :

```bash
rm -rf ./ssh/ # a ne surtout pas faire sans backup
```

🎯 Prochaines étapes :
Copiez la clé publique ci-dessus et ajoutez-la à GitHub
Configurez les secrets GitHub Actions avec votre clé privée et informations Proxmox
Utilisez la clé publique dans votre configuration Terraform

## 📚 Références

- [Documentation GitHub SSH](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [Documentation GitHub Actions](https://docs.github.com/en/actions)
- [Documentation Terraform](https://www.terraform.io/docs)
- [Documentation Proxmox](https://pve.proxmox.com/pve-docs/)

---

**Note** : Ce script est conçu pour être utilisé dans le cadre du projet Terraform Proxmox. Assurez-vous d'avoir exécuté le script `2-create-user-proxmox.sh` avant de configurer les secrets GitHub Actions.
