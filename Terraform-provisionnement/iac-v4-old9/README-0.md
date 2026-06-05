# 0-main.sh - Pipeline IaC Terraform/Proxmox

Script principal d'orchestration qui automatise l'ensemble du pipeline Infrastructure as Code (IaC) pour Terraform et Proxmox.

## 🚀 Fonctionnalités

- **Orchestration complète** : Enchaîne automatiquement les scripts 1, 2, 3, 4 et 5
- **Pipeline 8 étapes** : SSH → User Proxmox → Images Cloud → Templates VMs → Config Terraform → Déploiement
- **Multiplexing SSH** : Connexion SSH persistante pour une seule saisie de mot de passe
- **Gestion d'erreurs** : Arrêt immédiat en cas d'échec (`set -euo pipefail`)
- **Automatique** : Récupère la clé SSH générée et l'envoie à Proxmox
- **Idempotent** : Peut être réexécuté sans problème

## 📋 Prérequis

- Accès SSH au serveur Proxmox (root)
- `scp` et `ssh` installés
- Scripts `1-generate-ssh-keys.sh`, `2-create-user-proxmox.sh`, `3-cloud-init-images.sh`, `4-template-generique.sh` et `5-generate-terraform-config.sh` présents

## 🛠️ Utilisation

### Exécution simple

```bash
chmod +x 0-main.sh
./0-main.sh
```

Le script vous demandera **une seule fois** le mot de passe root de Proxmox.

## 📁 Flux d'exécution

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   0-main.sh     │────▶│ 1-generate-ssh   │────▶│ 2-create-user   │
│  (Orchestrateur)│     │    -keys.sh      │     │  -proxmox.sh    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
        │                        │                       │
        │                        ▼                       ▼
        │               ┌─────────────────┐     ┌─────────────────┐
        │               │  ./ssh/         │     │  Proxmox User   │
        │               │  ├── clé privée │     │  ├── terraform@pve
        │               │  ├── clé publique      ├── TerraformRole
        │               │  └── configs    │     │  ├── API Token
        │               └─────────────────┘     │  └── terraform-config.txt
        │                                       └─────────────────┘
        │                                               │
        │                       ┌───────────────────┐   │
        │                       ▼                   ▼   │
        │               ┌─────────────────┐   ┌─────────────────┐
        │               │ 3-cloud-init    │   │ 4-template      │
        │               │   -images.sh    │──▶│  -generique.sh  │
        │               └─────────────────┘   └─────────────────┘
        │                        │                       │
        │                        ▼                       ▼
        │               ┌─────────────────┐     ┌─────────────────┐
        │               │ Cloud Images    │     │ VM Templates    │
        │               │ (QCOW2/IMG)     │     │ 9001: debian-13 │
        │               └─────────────────┘     │ 9002: ubuntu-24 │
        │                                       │ 9003: ubuntu-26 │
        │                                       └─────────────────┘
        │                                               │
        │                                               ▼
        │                               ┌─────────────────────────┐
        │                               │ 5-generate-terraform-   │
        │                               │      config.sh          │
        │                               │  ├── vm-definitions.json│
        │                               │  └── terraform.tfvars │
        │                               └─────────────────────────┘
        │                                               │
        │                                               ▼
        │                               ┌─────────────────────────┐
        │                               │ 6-Déploiement Terraform │
        │                               │  ├── terraform init     │
        │                               │  ├── terraform plan     │
        │                               │  └── terraform apply    │
        │                               └─────────────────────────┘
        └───────────────────────────────────────────────┘
                    Multiplexing SSH (ControlMaster)
```

## 🔧 Étapes détaillées

| Étape | Action | Description |
|-------|--------|-------------|
| **0** | Activation multiplexing SSH | Crée une connexion persistante (10 min) |
| **1** | Génération des clés SSH | Exécute `1-generate-ssh-keys.sh` en local |
| **2** | Création du dossier distant | Crée `/home/kevin-stage-devops/` sur Proxmox |
| **3** | Envoi des scripts | Copie scripts 2, 3 et 4 via SCP |
| **4** | Permissions | Rend les scripts exécutables sur Proxmox |
| **5** | Création user Proxmox | Exécute `2-create-user-proxmox.sh` avec la clé SSH |
| **6** | Téléchargement images | Exécute `3-cloud-init-images.sh` (images cloud) |
| **7** | Création templates | Exécute `4-template-generique.sh` (VMs 9001-9003) |
| **8** | **Suppression VMs existantes** | Nettoyage idempotent avant déploiement |
| **8.1** | Récupération VMID | Parse `terraform.tfvars` pour VMID start |
| **8.2** | Affichage cibles | Liste les VMID à recréer |
| **8.3** | Vérification VMs | Check chaque VMID sur Proxmox (qm status) |
| **8.4** | Suppression VMs | Stop + destroy des VMs existantes |
| **9** | **Déploiement Terraform** | Orchestration terraform (optionnel) |
| **9.0** | Confirmation | Demande confirmation déploiement |
| **9.1** | Nettoyage state | Suppression `tfstate`, `.terraform`, lock |
| **9.2** | Init | `terraform init` |
| **9.3** | Refresh | `terraform refresh` (sync avec Proxmox) |
| **9.4** | Plan | `terraform plan -out=tfplan` |
| **9.5** | Confirmation apply | Demande confirmation finale |
| **9.6** | Apply | `terraform apply tfplan` |
| **10** | **Déploiement Ansible** | Exécute `6-deploiement-ansible.sh` (optionnel) |
| **11** | **Déploiement Moodle** | Exécute `7-deploy-moodle.sh` avec reset-db (optionnel) |

## 🔐 Multiplexing SSH (ControlMaster)

Le script utilise le multiplexing SSH pour optimiser les connexions :

```bash
SSH_OPTS="-o ControlMaster=auto -o ControlPersist=10m -o ControlPath=~/.ssh/ctrl/proxmox-ctrl-%r@%h:%p"
```

**Avantages :**
- ✅ Une seule saisie de mot de passe pour tout le pipeline
- ✅ Connexion réutilisée pour SCP et SSH
- ✅ Timeout automatique après 10 minutes

## 📤 Paramètres transférés

Le script passe automatiquement ces arguments à `2-create-user-proxmox.sh` :

| Argument | Valeur | Description |
|----------|--------|-------------|
| `$1` | Contenu de la clé publique | Clé SSH générée par le script 1 |
| `$2` | `/home/kevin-stage-devops/terraform-config.txt` | Chemin du fichier de sortie |

## 🎉 Résultat final

Après exécution, vous obtenez :

```
🎉 Pipeline IaC terminé avec succès.

Résultats :
├── Local
│   ├── ./ssh/id_ed25519_terraform-proxmox (clé privée)
│   ├── ./ssh/id_ed25519_terraform-proxmox.pub (clé publique)
│   ├── ./ssh/terraform-ssh-config.txt (config SSH)
│   └── ./ssh/github-actions-example.yml (workflow CI/CD)
│
└── Proxmox Server
    ├── Utilisateur & Permissions
    │   ├── terraform@pve (utilisateur)
    │   ├── TerraformRole (rôle avec permissions)
    │   ├── API Token (token d'authentification)
    │   └── /root/.ssh/id_ed25519_terraform-proxmox.pub (clé SSH)
    │
    ├── Configuration
    │   └── /home/kevin-stage-devops/terraform-config.txt (config Terraform)
    │
    ├── Cloud Images
    │   └── /var/lib/vz/template/cloud-init-images/
    │       ├── debian-13-generic-amd64.qcow2
    │       └── ubuntu-24.04-server-cloudimg-amd64.img
    │
    └── VM Templates ⭐ NOUVEAU
        ├── 9001: debian-13-cloud (Template)
        ├── 9002: ubuntu-24.04-cloud (Template)
        └── 9003: ubuntu-26.04-cloud (Template)

✅ DÉPLOIEMENT TERRAFORM ⭐ NOUVEAU
├── Config générée
│   ├── Terraform/terraform.tfvars
│   └── vm-definitions.json (config utilisateur)
└── VMs déployées (si confirmé)
    ├── test-vm-kevin (192.168.20.200)
    └── app-server (192.168.20.201)
```

## � Paramètres et exemples d'utilisation

### Arguments disponibles

| Paramètre | Valeurs | Description | Défaut |
|-----------|---------|-------------|--------|
| `$1` / `SCRIPT3_ARG` | `debian` `24.04` `26.04` `all` | Images cloud-init à télécharger | `all` |
| `ENV_FILE` | chemin | Fichier de config global | `env.conf` |

### Exemples de commandes

```bash
# Exécution standard (télécharge toutes les images)
./0-main.sh

# Déploiement Debian uniquement
./0-main.sh debian

# Ubuntu 24.04 uniquement
./0-main.sh 24.04

# Ubuntu 26.04 uniquement
./0-main.sh 26.04

# Avec env.conf personnalisé
ENV_FILE=/path/to/custom.env ./0-main.sh
```

### Variables d'environnement clés (env.conf)

| Variable | Exemple | Description |
|----------|---------|-------------|
| `PM_HOST` | `192.168.0.1` | IP Proxmox |
| `PM_SSH_USER` | `root` | Utilisateur SSH Proxmox |
| `SCRIPT3_ARG` | `debian` | Mode téléchargement images |
| `TEMPLATE_ID` | `9001` | Template VM (9001=Debian, 9002=Ubuntu24, 9003=Ubuntu26) |
| `VM_SSH_USER` | `terraform` | Utilisateur SSH VMs |
| `VM_PASSWORD` | `changeme` | Mot de passe VMs (mode dev) |
| `NET_BRIDGE` | `vmbr1` | Bridge réseau |
| `AUTO_DEPLOY_MOODLE` | `true` `false` | Déploiement Moodle automatique | `true` |

### Exemple complet: Déploiement Debian spécifique

```bash
# 1. Configurer env.conf
cat env.conf | grep -E "SCRIPT3_ARG|TEMPLATE_ID"
# SCRIPT3_ARG="debian"
# TEMPLATE_ID="9001"

# 2. Lancer le pipeline
./0-main.sh debian

# Output attendu:
# ☁️  Téléchargement des images Cloud-init sur Proxmox (mode: debian)...
# 📦 Création des templates Proxmox...
# ⚙️  Régénération forcée de la configuration Terraform...
# 🔍 [8.1] Récupération des VMID depuis terraform.tfvars...
# 📋 [8.2] VMID cibles (à recréer): 200 - 201
# 🔍 [8.3] Vérification des VMs existantes sur Proxmox...
# 🧹 [8.4] Nettoyage des VMs terminé
# 🚀 [9.0] Lancer le déploiement Terraform maintenant ? (y/N) : y
# 🧹 [9.1] Nettoyage du state Terraform...
# 🔄 [9.2] Initialisation Terraform...
```

## 🎓 Déploiement Moodle (Étape 11)

Le pipeline inclut une étape optionnelle de déploiement Moodle sur K3s via le script `7-deploy-moodle.sh`.

### Variables d'environnement

| Variable | Valeurs | Description | Défaut |
|----------|---------|-------------|--------|
| `AUTO_DEPLOY_MOODLE` | `true` `false` | Active/désactive le déploiement Moodle automatique | `true` |

### Options du script 7-deploy-moodle.sh

Le script `7-deploy-moodle.sh` accepte les arguments suivants :

| Argument | Description |
|----------|-------------|
| `build` | Build l'image Docker et push vers Harbor |
| `skip-build` | Skip le build (utilise l'image existante) |
| `reset-db` | Reset la base de données PostgreSQL et recrée Moodle |

### Utilisation

```bash
# Déploiement automatique (défaut)
./0-main.sh

# Ignorer le déploiement Moodle
AUTO_DEPLOY_MOODLE=false ./0-main.sh

# Déploiement manuel avec reset DB
./7-deploy-moodle.sh reset-db

# Déploiement manuel sans build
./7-deploy-moodle.sh skip-build
```

### Processus de déploiement Moodle

1. **Build image Docker** (optionnel) : Build l'image Moodle depuis `docker-images/moodle/Dockerfile`
2. **Push vers Harbor** : Push l'image vers `192.168.20.205/library/moodle:latest`
3. **Reset DB** (si `reset-db`) : Supprime et recrée la base PostgreSQL Moodle
4. **Suppression ancien deployment** : Supprime le deployment K3s existant
5. **Déploiement Ansible** : Exécute `ansible-playbook playbooks/deploy_moodle.yml`
6. **Vérification** : Attend que le pod Moodle soit prêt

### Accès Moodle

Après déploiement, Moodle est accessible via :
- **IP directe** : `http://192.168.20.220:30081`
- **FQDN** : `http://moodle.greencontracts.lan` (si DNS configuré)

### Commandes utiles

```bash
# Logs Moodle
ssh ubuntu@192.168.20.220 'sudo k3s kubectl logs -n moodle deployment/moodle -f'

# Shell dans le pod Moodle
ssh ubuntu@192.168.20.220 'sudo k3s kubectl exec -n moodle deployment/moodle -it -- bash'

# Status des pods Moodle
ssh ubuntu@192.168.20.220 'sudo k3s kubectl get pods -n moodle'
```

### Note importante

Le déploiement Moodle utilise par défaut l'option `reset-db` pour créer la base de données au premier déploiement. Si la base existe déjà, elle sera supprimée et recréée. Pour éviter cela, utilisez `skip-build` à la place.

## �🚨 Dépannage

| Erreur | Cause | Solution |
|--------|-------|----------|
| `No such file or directory` | Le dossier distant n'existe pas | Le script le crée automatiquement |
| `Permission denied` | Mauvais mot de passe | Vérifiez les credentials root |
| `Connection refused` | SSH non accessible | Vérifiez le firewall et le service SSH |
| `SCRIPT1 introuvable` | Mauvais nom de fichier | Vérifiez que `1-generate-ssh-keys.sh` existe |

## 🔧 Configuration

Modifiez ces variables dans le script si nécessaire :

```bash
PROXMOX_HOST="192.168.0.1"                    # IP du serveur Proxmox
PROXMOX_USER="root"                           # Utilisateur SSH

# Scripts locaux (à exécuter sur votre machine)
SCRIPT1="./1-generate-ssh-keys.sh"              # Génération des clés SSH
SCRIPT2="./2-create-user-proxmox.sh"          # Création user Proxmox
SCRIPT3="./3-cloud-init-images.sh"            # Téléchargement images cloud
SCRIPT4="./4-template-generique.sh"           # Création des templates VMs
SCRIPT5="./5-generate-terraform-config.sh"    # Génération config Terraform

# Chemins distants sur Proxmox
REMOTE_DIR="/home/kevin-stage-devops"
SSH_KEY_PATH="./ssh/id_ed25519_terraform-proxmox.pub"

# Argument pour le script 3 (debian, 24.04, 26.04, ou all)
SCRIPT3_ARG="${1:-debian}"  # Par défaut: télécharge uniquement Debian
```

## 📚 Documentation des scripts

| Script | Description | Lien |
|--------|-------------|------|
| **1** | Génération des clés SSH | [README-1.md](README-1.md) |
| **2** | Création user Proxmox | [README-2.md](README-2.md) |
| **3** | Téléchargement images cloud-init | [README-3.md](README-3.md) ⭐ |
| **4** | Création des templates VMs | [README-4.md](README-4.md) ⭐ |
| **5** | Génération config Terraform | [README-5.md](README-5.md) ⭐ |

---

**Note** : Ce script doit être exécuté depuis votre machine locale, pas depuis Proxmox.
