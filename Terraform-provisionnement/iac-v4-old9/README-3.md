# 3-cloud-init-images.sh - Téléchargement des Images Cloud-Init

Script modulaire et idempotent pour télécharger des images cloud-init (QCOW2/IMG) de Debian et Ubuntu, avec vérification automatique des fichiers existants.

## 📋 Description

Ce script automatise le téléchargement des images cloud-init officielles depuis les miroirs Debian et Ubuntu. Il est conçu pour être :

- **Idempotent** : Ne retélécharge pas les images existantes
- **Flexible** : Permet de choisir quelle image télécharger
- **Robuste** : Vérifie la taille des fichiers pour détecter les downloads incomplets
- **Résilient** : Ignore les erreurs non critiques (ex: repos Proxmox Enterprise)

## 🚀 Utilisation

### Mode 1 : Téléchargement sélectif (recommandé)

Télécharge une image spécifique :

```bash
./3-cloud-init-images.sh debian      # Debian 13 uniquement
./3-cloud-init-images.sh 24.04       # Ubuntu 24.04 LTS
./3-cloud-init-images.sh 26.04       # Ubuntu 26.04 (Daily)
./3-cloud-init-images.sh all         # Toutes les images
```

### Mode 2 : Avec arguments

```bash
./3-cloud-init-images.sh <target>
```

**Arguments valides :**

| Argument | Image téléchargée |
|----------|-------------------|
| `debian`, `debian13` | Debian 13 (Trixie) |
| `24.04`, `ubuntu24`, `noble` | Ubuntu 24.04 LTS |
| `26.04`, `ubuntu26`, `daily` | Ubuntu 26.04 (Daily Build) |
| `all` ou vide | Toutes les images |

### Mode 3 : Dans un autre script

```bash
#!/bin/bash
source ./3-cloud-init-images.sh

# Télécharger uniquement Debian
download_debian

# Télécharger Ubuntu 24.04
download_ubuntu_24

# Afficher les résultats
ls -lh "$DEST_DIR"
```

## ⚙️ Configuration

### Variables de configuration

| Variable | Défaut | Description |
|----------|--------|-------------|
| `DEST_DIR` | `/home/kevin-stage-devops/cloud-images` | Dossier de téléchargement local |
| `ISO_DIR` | `/var/lib/vz/template/cloud-init-images` | Dossier de copie pour Proxmox |

### Images configurées

| Image | Nom du fichier | URL source | Taille typique |
|-------|----------------|------------|----------------|
| **Debian 13** | `debian-13-generic-amd64.qcow2` | `cloud.debian.org` | ~400MB |
| **Ubuntu 24.04** | `ubuntu-24.04-server-cloudimg-amd64.img` | `cloud-images.ubuntu.com` | ~500MB |
| **Ubuntu 26.04** | `ubuntu-26.04-server-cloudimg-amd64.img` | `cloud-images.ubuntu.com` | ~600MB |

## 🔍 Logique d'idempotence

Le script utilise une double vérification pour éviter les téléchargements inutiles :

### 1. Vérification exacte (nom de fichier)
```
[INFO 3.1] Debian 13 existe déjà (nom exact) : debian-13-generic-amd64.qcow2 (415M)
```

### 2. Vérification par pattern (fallback)
Si le nom diffère légèrement (version legacy), recherche avec pattern `*debian*13*.qcow2` :
```
[WARN 3.2] Image Debian 13 trouvée avec nom différent : debian-13-genericcloud-amd64.qcow2
[WARN 3.2] Attendu : debian-13-generic-amd64.qcow2 - Version legacy ou variante détectée
[INFO 3.2] Utilisation de l'image existante (415M)
```

### 3. Vérification de taille
Détecte les fichiers corrompus/incomplets (< 100MB) et les retélécharge :
```
[WARN 3.1] Fichier existant trop petit (1536000 bytes) - retéléchargement...
```

## 📁 Emplacements des fichiers

### Après téléchargement

```
/home/kevin-stage-devops/
└── cloud-images/
    ├── debian-13-generic-amd64.qcow2      (~415 MB)
    ├── ubuntu-24.04-server-cloudimg-amd64.img   (~500 MB)
    └── ubuntu-26.04-server-cloudimg-amd64.img   (~600 MB)
```

### Après copie vers dossier Proxmox

Le script copie automatiquement les images vers :

```
/var/lib/vz/template/cloud-init-images/
├── debian-13-generic-amd64.qcow2
├── ubuntu-24.04-server-cloudimg-amd64.img
└── ubuntu-26.04-server-cloudimg-amd64.img
```

Ce dossier est le standard Proxmox pour les images de templates.

## 🎯 Intégration Pipeline

Ce script est l'étape 3 du pipeline global `0-main.sh`. Il est exécuté automatiquement après la création du user Proxmox.

### Séquence dans 0-main.sh

```bash
# Étape 3 (ce script)
echo "☁️  Téléchargement des images Cloud-init sur Proxmox (mode: debian)..."
ssh root@proxmox "/home/kevin-stage-devops/3-cloud-init-images.sh debian"

# Étape 4 (template-generique)
echo "📦 Création des templates Proxmox..."
ssh root@proxmox "/home/kevin-stage-devops/4-template-generique.sh"
```

### Dépendances

- **Sortie** : Fichiers QCOW2/IMG téléchargés
- **Entrée** pour script 4 : Images utilisées par `4-template-generique.sh` pour créer les VM templates

## 🔧 Fonctions disponibles

### `check_dependencies()`
Vérifie que `wget` est installé. `libguestfs-tools` est optionnel (pour personnalisation avancée).

### `create_directory()`
Crée les dossiers `DEST_DIR` et `ISO_DIR` si inexistants.

### `download_debian()`
Télécharge Debian 13 avec vérification d'idempotence.

### `download_ubuntu_24()`
Télécharge Ubuntu 24.04 LTS avec vérification d'idempotence.

### `download_ubuntu_26()`
Télécharge Ubuntu 26.04 (daily build). Peut échouer si le daily n'est pas disponible.

### `main()`
Point d'entrée principal qui orchestre les téléchargements selon l'argument fourni.

## 📊 Exemple de sortie

### Premier téléchargement

```
=== Téléchargement Images Cloud-Init ===
Mode: debian

[INFO 1.1] Vérification des dépendances...
[INFO 1.5] Dépendances OK
[INFO 2.1] Préparation du dossier /home/kevin-stage-devops/cloud-images...
[INFO 2.2] Dossier existe déjà
[INFO 2.3] Préparation du dossier /var/lib/vz/template/cloud-init-images...
[INFO 2.4] Dossier existe déjà
[INFO 3.2] Téléchargement Debian 13...
--2024-04-29 10:26:01--  https://cloud.debian.org/images/cloud/trixie/...
Saving to: '/home/kevin-stage-devops/cloud-images/debian-13-generic-amd64.qcow2'

debian-13-generic-amd64.qcow2     100%[================================>] 415.00M  25.5MB/s    in 16s

[INFO 3.4] Debian 13 téléchargé (415M)

=== Vérification des fichiers ===
total 415M
-rw-r--r-- 1 root root 415M Apr 29 10:26 debian-13-generic-amd64.qcow2

=== Copie vers le dossier ISO si nécessaire ===
[INFO 6.1] Téléchargement terminé
[INFO 6.2] Images dans: /home/kevin-stage-devops/cloud-images
```

### Exécution idempotente (image déjà présente)

```
=== Téléchargement Images Cloud-Init ===
Mode: debian

[INFO 1.1] Vérification des dépendances...
[INFO 1.5] Dépendances OK
[INFO 3.1] Debian 13 existe déjà (nom exact) : debian-13-generic-amd64.qcow2 (415M)
[INFO 6.1] Téléchargement terminé
```

## 🚨 Dépannage

| Erreur | Cause | Solution |
|--------|-------|----------|
| `wget: command not found` | Package non installé | Le script tente d'installer `wget` automatiquement |
| `401 Unauthorized` (Proxmox repos) | Repos Enterprise Proxmox | Ignoré automatiquement, non bloquant |
| `Image introuvable` | URL invalide ou image retirée | Vérifiez les URLs dans le script |
| Téléchargement très lent | Bande passante limitée | Normal pour ~400-600MB |
| `Fichier trop petit` | Download incomplet | Le script retélécharge automatiquement |

## 📝 Notes

### Images Cloud-Init vs ISO traditionnelles

| Caractéristique | Cloud-Init | ISO traditionnelle |
|-----------------|------------|-------------------|
| Taille | ~400-600 MB | ~1-2 GB |
| Boot | Rapide (config pré-intégrée) | Lent (installation complète) |
| Personnalisation | Via cloud-init | Manuelle ou preseed |
| Terraform | Optimisé | Nécessite plus de configuration |

### Formats supportés

- **QCOW2** : Format QEMU/KVM (recommandé pour Proxmox)
- **IMG** : Format raw compatible
- **VMDK** : Non supporté nativement (nécessite conversion)

## 🔗 Voir aussi

- [README-0.md](README-0.md) - Pipeline complet (orchestration)
- [README-2.md](README-2.md) - Création user Proxmox (étape précédente)
- [README-4.md](README-4.md) - Création templates VMs (étape suivante)
- [Debian Cloud Images](https://cloud.debian.org/images/cloud/)
- [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/)

---

**Note** : Ce script s'exécute sur le serveur Proxmox (pas sur votre machine locale). Il est automatiquement copié et exécuté via `0-main.sh`.
