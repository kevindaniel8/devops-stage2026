# README - Script 5: Génération Config Terraform

## 📋 Description

Ce script génère automatiquement le fichier `terraform.tfvars` à partir :
- Des credentials Proxmox récupérés depuis le serveur
- D'un fichier de configuration JSON externe (`vm-definitions.json`)
- Des **paramètres réseau définis dans `env.conf`** (gateway, dns_server, subnet, net_bridge)
- Des clés SSH générées précédemment

## 🎯 Objectif

Permettre à un utilisateur de configurer ses VMs **sans modifier le script**, en éditant simplement un fichier JSON.

## 📁 Fichiers impliqués

| Fichier | Description |
|---------|-------------|
| `5-generate-terraform-config.sh` | Script principal |
| `env.conf` | **Configuration réseau** - Gateway, DNS, Subnet, Bridge (PRIORITAIRE) |
| `vm-definitions.json` | **Configuration VMs** - Définition des VMs uniquement (pas de réseau) |
| `Terraform/terraform.tfvars` | Fichier généré (sortie) |
| `~/.ssh/id_ed25519_terraform-proxmox.pub` | Clé SSH publique |
| `/home/kevin-stage-devops/terraform-config.txt` | Tokens API sur Proxmox |

## ⚙️ Configuration

### Variables d'environnement (optionnel)

**Configuration réseau (depuis `env.conf` - PRIORITAIRE) :**
```bash
export NET_BRIDGE="vmbr1"           # Bridge réseau
export GATEWAY="192.168.20.1"       # Gateway par défaut
export DNS_SERVER="8.8.8.8"         # Serveur DNS
export SUBNET="192.168.20"          # Sous-réseau (pour calcul des IPs)
```

**Configuration Proxmox et VMs :**
```bash
export PM_HOST="192.168.0.1"        # IP Proxmox
export PROXMOX_NODE="pve"            # Nom du node
export SSH_USER="terraform"         # Utilisateur SSH
export TEMPLATE_ID="9001"           # ID du template (9001=Debian, 9002=Ubuntu24, 9003=Ubuntu26)
export VM_CONFIG_FILE="/chemin/vers/vm-definitions.json"  # Fichier de config VMs
```

### Structure du fichier JSON

⚠️ **IMPORTANT : La configuration réseau a été déplacée dans `env.conf`**

Le fichier `vm-definitions.json` ne contient plus la section `network`. 
Les paramètres réseau (gateway, dns_server, subnet) sont désormais définis **uniquement** dans `env.conf`.

```json
{
  "_comment": "Fichier de configuration des VMs",
  "_network_config": "⚠️ Config réseau dans env.conf UNIQUEMENT",
  "vmid_start": 200,
  "vms": [
    {
      "name": "nom-de-la-vm",
      "ip_suffix": 200,
      "cores": 2,
      "memory": 2048,
      "disk": 20,
      "description": "Description de la VM"
    }
  ]
}
```

#### Champs des VMs

| Champ | Type | Description | Exemple |
|-------|------|-------------|---------|
| `name` | string | Nom unique de la VM | `test-vm` |
| `ip_suffix` | number | Dernier octet de l'IP | `200` → IP: `192.168.20.200` |
| `cores` | number | Nombre de cœurs CPU | `2` |
| `memory` | number | RAM en Mo | `2048` |
| `disk` | number | Taille disque en Go | `20` |
| `description` | string | Commentaire | `VM de test` |

## 🚀 Utilisation

### Étape 1: Configurer les VMs

```bash
nano /home/kevin/devops-stage2026/Terraform-provisionnement/vm-definitions.json
```

Modifier selon vos besoins :
```json
{
  "vms": [
    {
      "name": "prod-web",
      "ip_suffix": 210,
      "cores": 4,
      "memory": 8192,
      "disk": 100,
      "description": "Serveur web production"
    }
  ]
}
```

### Étape 2: Générer la configuration

```bash
./5-generate-terraform-config.sh
```

### Étape 3: Modifier le mot de passe (mode dev)

```bash
nano Terraform/terraform.tfvars
# Changer: vm_password = "votre-mot-de-passe-secure"
```

### Étape 4: Déployer avec Terraform

```bash
cd Terraform
terraform init
terraform plan
terraform apply
```

## 📤 Exemple de sortie

```
===============================================
  Génération Config Terraform
===============================================

[INFO] Récupération du token API depuis Proxmox...
[OK] Token ID trouvé: terraform@pve!tokenTerraform
[OK] Token secret récupéré depuis terraform-config.txt
[OK] Fichier de configuration VMs trouvé: .../vm-definitions.json
[INFO] Génération de .../Terraform/terraform.tfvars...
[OK] Fichier généré: .../Terraform/terraform.tfvars

--- Récapitulatif ---
  Proxmox Host:   192.168.0.1
  Proxmox Node:   pve
  Template ID:    9001
  SSH User:       terraform
  VMID Start:     200
  Gateway:        192.168.20.1
  Config VMs:     .../vm-definitions.json
  VMs définies:   3

Prochaines étapes:
  1. Configurer les VMs: nano .../vm-definitions.json
  2. Modifier le mot de passe: nano .../Terraform/terraform.tfvars (vm_password)
  3. Regénérer la config: ./5-generate-terraform-config.sh
  4. cd .../Terraform
  5. terraform plan
  6. terraform apply
```

## � Paramètres et exemples

### Variables d'environnement

| Variable | Exemple | Description | Obligatoire |
|----------|---------|-------------|-------------|
| `PM_HOST` | `192.168.0.1` | IP du serveur Proxmox | ✅ Oui |
| `PROXMOX_NODE` | `pve` | Nom du node Proxmox | ✅ Oui |
| `SSH_USER` | `terraform` | Utilisateur SSH pour les VMs | ✅ Oui |
| `TEMPLATE_ID` | `9001` | ID du template (9001=Debian, 9002=Ubuntu24, 9003=Ubuntu26) | ✅ Oui |
| `NET_BRIDGE` | `vmbr1` | Bridge réseau Proxmox | ✅ Oui (dans env.conf) |
| `GATEWAY` | `192.168.20.1` | Gateway par défaut des VMs | ✅ Oui (dans env.conf) |
| `DNS_SERVER` | `8.8.8.8` | Serveur DNS des VMs | ✅ Oui (dans env.conf) |
| `SUBNET` | `192.168.20` | Sous-réseau pour calcul des IPs | ✅ Oui (dans env.conf) |
| `VM_CONFIG_FILE` | `vm-definitions.json` | Chemin fichier config VMs | ❌ Non (défaut: vm-definitions.json) |
| `VMID_START` | `200` | Premier VMID | ❌ Non (défaut: 200) |

### Exemples d'utilisation

```bash
# Exécution standard
./5-generate-terraform-config.sh

# Avec variables d'environnement
export PM_HOST="192.168.0.1"
export PROXMOX_NODE="pve"
export TEMPLATE_ID="9002"
export VM_CONFIG_FILE="vm-definitions-infra.json"
./5-generate-terraform-config.sh

# Ligne de commande inline
PM_HOST="192.168.1.10" PROXMOX_NODE="pve1" TEMPLATE_ID="9001" ./5-generate-terraform-config.sh

# Génération pour Debian
export TEMPLATE_ID="9001"
./5-generate-terraform-config.sh

# Génération pour Ubuntu 24.04
export TEMPLATE_ID="9002"
./5-generate-terraform-config.sh
```

### Exemple complet: Génération config infra

```bash
# 1. Vérifier le fichier de config VMs
cat vm-definitions.json

# 2. Lancer la génération
./5-generate-terraform-config.sh

# Output attendu:
# ===============================================
#   Génération Config Terraform
# ===============================================
# [INFO] Récupération du token API depuis Proxmox...
# [OK] Token ID trouvé: terraform@pve!tokenTerraform
# [OK] Fichier de configuration VMs trouvé: vm-definitions.json
# [INFO] Génération de Terraform/terraform.tfvars...
# [OK] Fichier généré: Terraform/terraform.tfvars
#
# --- Récapitulatif ---
#   Proxmox Host:   192.168.0.1
#   Proxmox Node:   pve
#   Template ID:    9001
#   SSH User:       terraform
#   VMID Start:     200
#   VMs définies:   2
```

## �🔧 Dépendances

- `jq` : Pour parser le fichier JSON (optionnel mais recommandé)
- `ssh` : Pour récupérer les tokens depuis Proxmox
- Clé SSH générée par le script 1

Installation de jq si manquant :
```bash
sudo apt-get install jq
```

## 📝 Notes

- Le script **écrase toujours** `terraform.tfvars` lors de l'exécution
- **⚠️ Changement majeur :** La configuration réseau ne se fait plus dans `vm-definitions.json` mais **uniquement** dans `env.conf`
- Modifiez `env.conf` pour changer le réseau (gateway, dns, subnet, bridge)
- Modifiez uniquement `vm-definitions.json` pour changer les VMs (structure, ressources)
- Le token secret est récupéré automatiquement depuis le serveur Proxmox
- En mode `dev`, un mot de passe est configuré (à changer pour la production)
- En mode `prod`, seule la clé SSH est utilisée

### ⚠️ Migration depuis l'ancienne version

Si vous aviez une section `network` dans `vm-definitions.json` :
```json
// AVANT (dans vm-definitions.json)
{
  "network": {
    "gateway": "192.168.20.1",
    "dns_server": "8.8.8.8",
    "subnet": "192.168.20"
  }
}
```

**Déplacez ces valeurs dans `env.conf` :**
```bash
# APRÈS (dans env.conf)
NET_BRIDGE="vmbr1"
GATEWAY="192.168.20.1"
DNS_SERVER="8.8.8.8"
SUBNET="192.168.20"
```

## 🔗 Intégration Pipeline

Ce script fait partie de la pipeline complète :

```
0-main.sh → 5-generate-terraform-config.sh → terraform apply
     ↓
1-generate-ssh-keys.sh
2-create-user-proxmox.sh
3-cloud-init-images.sh
4-template-generique.sh
```

## 📚 Voir aussi

- [README-0.md](README-0.md) - Orchestration principale
- [README-3.md](README-3.md) - Téléchargement images cloud-init
- [README-4.md](README-4.md) - Création templates VM
- [Terraform/main.tf](Terraform/main.tf) - Configuration Terraform
