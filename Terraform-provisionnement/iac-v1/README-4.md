# 4-template-generique.sh - Création de Templates Proxmox Cloud-Init

Script modulaire pour créer des templates de machines virtuelles Proxmox à partir d'images cloud-init (QCOW2).

## 📋 Description

Ce script automatise la création de templates Proxmox optimisés pour Terraform :
- Import d'images cloud-init (Debian, Ubuntu, etc.)
- Configuration cloud-init activée
- Disques redimensionnables
- Console série pour accès VGA
- Conversion automatique en template

## 🚀 Utilisation

### Mode 1 : Sans argument (Templates par défaut)

Crée automatiquement les templates Debian 13 et Ubuntu 24.04 :

```bash
./4-template-generique.sh
```

### Mode 2 : Template personnalisé

Crée un template avec des paramètres spécifiques :

```bash
./4-template-generique.sh <vm_id> <vm_name> <image_path> [storage] [bridge] [memory] [cores] [disk_size]
```

**Exemples :**
```bash
# Debian 13 basique
./4-template-generique.sh 9001 debian-13 /var/lib/vz/template/cloud-init-images/debian-13-generic-amd64.qcow2

# Ubuntu 24.04 avec 4GB RAM et 2 cores
./4-template-generique.sh 9002 ubuntu-24 /path/to/ubuntu.img local-lvm vmbr0 4096 2 20G

# Template personnalisé complet
./4-template-generique.sh 9003 ubuntu-26 /path/to/ubuntu26.img local-lvm vmbr0 4096 4 30G
```

### Mode 3 : Fonction dans un autre script

```bash
#!/bin/bash
source ./4-template-generique.sh

# Créer un template spécifique
create_template 9001 "debian-13" "/path/debian.qcow2"

# Ou créer plusieurs templates
VM_IDS=(9001 9002 9003)
VM_NAMES=(debian-13 ubuntu-24 ubuntu-26)
IMAGE_PATHS=(/path/d.qcow2 /path/u24.img /path/u26.img)

for i in "${!VM_IDS[@]}"; do
    create_template "${VM_IDS[$i]}" "${VM_NAMES[$i]}" "${IMAGE_PATHS[$i]}"
done
```

## ⚙️ Paramètres

| Argument | Description | Défaut | Obligatoire |
|----------|-------------|--------|-------------|
| `vm_id` | ID numérique de la VM (100-999999) | `9001` | Mode 2 ✓ |
| `vm_name` | Nom du template | `debian-13-cloud` | Mode 2 ✓ |
| `image_path` | Chemin vers l'image QCOW2/IMG | - | Mode 2 ✓ |
| `storage` | Pool de stockage Proxmox | `local-lvm` | ✗ |
| `bridge` | Interface réseau bridge | `vmbr0` | ✗ |
| `memory` | Mémoire en MB | `2048` | ✗ |
| `cores` | Nombre de cores CPU | `1` | ✗ |
| `disk_size` | Taille du disque | `10G` | ✗ |

## 🎯 Templates par défaut

Sans argument, le script crée :

| VM ID | Nom | Image | Cores | RAM | Disk |
|-------|-----|-------|-------|-----|------|
| `9001` | `debian-13-cloud` | `debian-13-generic-amd64.qcow2` | 1 | 2048M | 10G |
| `9002` | `ubuntu-24.04-cloud` | `ubuntu-24.04-server-cloudimg-amd64.img` | 2 | 2048M | 10G |

## 🔧 Fonctions disponibles

### `create_template()`

Fonction principale pour créer un template.

**Arguments :**
```bash
create_template vm_id vm_name image_path [storage] [bridge] [memory] [cores] [disk_size]
```

**Retour :**
- `0` : Succès
- `1` : Erreur (image introuvable, échec création VM, etc.)

### `create_default_templates()`

Crée les templates Debian + Ubuntu par défaut.

## 📁 Prérequis

### Images cloud-init

Les images doivent être présentes dans `/var/lib/vz/template/cloud-init-images/` :

```bash
# Téléchargement via le script 3-cloud-init-images.sh
./0-main.sh debian
```

Ou manuellement :
```bash
# Debian 13
wget -P /var/lib/vz/template/cloud-init-images/ \
  https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2

# Ubuntu 24.04
wget -P /var/lib/vz/template/cloud-init-images/ \
  https://cloud-images.ubuntu.com/noble/current/ubuntu-24.04-server-cloudimg-amd64.img
```

### Permissions Proxmox

Nécessite les privilèges root sur le nœud Proxmox pour exécuter les commandes `qm`.

## 🔄 Étapes de création

Le script effectue automatiquement :

1. **Validation** : Vérifie que l'image existe et les paramètres sont valides
2. **Cleanup** : Supprime une VM existante avec le même ID (idempotence)
3. **Création VM** : Crée la VM avec les ressources spécifiées
4. **Import disque** : Importe l'image cloud-init dans le storage
5. **Attachement** : Attache le disque en SCSI avec virtio
6. **Cloud-init** : Configure l'interface cloud-init et le boot order
7. **Resize** : Ajuste la taille du disque si nécessaire
8. **Template** : Convertit la VM en template

## 🛠️ Intégration Pipeline

Ce script est l'étape 4 du pipeline global. Il peut être :

1. **Exécuté via SSH** depuis `0-main.sh` :
   ```bash
   ssh root@proxmox /path/to/4-template-generique.sh
   ```

2. **Copié et exécuté** sur Proxmox :
   ```bash
   scp 4-template-generique.sh root@proxmox:/tmp/
   ssh root@proxmox "chmod +x /tmp/4-template-generique.sh && /tmp/4-template-generique.sh"
   ```

## 📊 Exemple de sortie

```
🚀 Création des templates par défaut (Debian + Ubuntu)

===============================
📦 Template 1/2 : Debian 13
===============================
===============================
🚀 Création template Proxmox
===============================
VM ID      : 9001
VM Name    : debian-13-cloud
Image      : /var/lib/vz/template/cloud-init-images/debian-13-generic-amd64.qcow2
Storage    : local-lvm
Bridge     : vmbr0
===============================
🛠️  Création VM...
📦 Import du disque...
💽 Attachement disque...
☁️  Configuration cloud-init...
📏 Resize disque...
📦 Conversion en template...
✅ Template créé avec succès !
👉 VM ID : 9001
👉 Nom   : debian-13-cloud

===============================
📦 Template 2/2 : Ubuntu 24.04
===============================
...

===============================
📊 RÉSUMÉ FINAL
===============================
✅ Succès : 2
❌ Échecs : 0
===============================
```

## 🔍 Vérification

```bash
# Lister les templates créés
qm list | grep -E '(9001|9002)'

# Détails d'un template
qm config 9001
```

## 📝 Notes

- **Idempotence** : Si une VM avec le même ID existe, elle est automatiquement supprimée
- **Images compatibles** : Toute image cloud-init au format QCOW2 ou IMG
- **Non destructif** : Les templates existants ne sont pas modifiés (sauf ID identique)
