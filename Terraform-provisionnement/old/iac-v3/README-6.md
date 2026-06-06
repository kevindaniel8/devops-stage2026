# README - Script 6: Déploiement Ansible

## 📋 Description

Ce script orchestre le déploiement des playbooks Ansible avec plusieurs modes d'exécution :
- **Défaut** : Déploiement complet (deploy_all)
- **Exécution directe** : Un ou plusieurs playbooks spécifiques
- **Menu interactif** : Sélection graphique des playbooks
- **Liste** : Affichage des playbooks disponibles
- **Syntax-check** : Vérification des playbooks

## 🎯 Objectif

Simplifier l'exécution Ansible en fournissant une interface unifiée pour déployer :
- L'infrastructure complète (pipeline CD, PostgreSQL, etc.)
- Un playbook spécifique
- Une sélection de playbooks multiples

## 📁 Fichiers impliqués

| Fichier | Description |
|---------|-------------|
| `6-deploiement-ansible.sh` | **Script principal** |
| `env.conf` | Configuration environnement (sourcé automatiquement) |
| `ansible/playbooks/*.yml` | Playbooks Ansible disponibles |
| `ansible/inventories/dev/hosts.yml` | Inventaire par défaut |

## 🚀 Utilisation

### Mode Défaut (sans paramètre)

Déploie automatiquement tout l'environnement (`deploy_all`) :

```bash
./6-deploiement-ansible.sh
```

### Exécution Directe (un ou plusieurs playbooks)

**Un seul playbook :**
```bash
./6-deploiement-ansible.sh pipeline_cd
```

**Plusieurs playbooks en séquence :**
```bash
./6-deploiement-ansible.sh pipeline_cd cluster-postgres
./6-deploiement-ansible.sh deploy_dns deploy_snmp deploy_reverse_proxy
```

### Options disponibles

| Option | Description |
|--------|-------------|
| `-h`, `--help`, `-?` | Affiche l'aide |
| `-m`, `--menu` | Lance le menu interactif |
| `-l`, `--list` | Liste tous les playbooks disponibles |
| `-c`, `--check` | Vérifie la syntaxe de tous les playbooks |

### Menu Interactif (`-m`)

```bash
./6-deploiement-ansible.sh -m
```

Affiche un menu numéroté :
```
╔════════════════════════════════════════════════╗
║     MENU DÉPLOIEMENT ANSIBLE - IAC-V3          ║
╚════════════════════════════════════════════════╝

Playbooks disponibles:

  [0] 🚀  Déploiement COMPLET (deploy_all)
  [1] 📦  Pipeline CD (Harbor + K3s + ArgoCD)
  [2] 🐘  Cluster PostgreSQL (Master + Replica)
  [3] 🌐  DNS (Bind9)
  [4] 🔄  Reverse Proxy
  [5] 📚  WikiJS
  [6] 📊  SNMP Monitoring

Autres options:
  [97] 🧹  Syntax-check all playbooks
  [98] 📋  Lister les playbooks disponibles
  [99] ❌  Quitter
```

## 📦 Playbooks disponibles

| Playbook | Description | Dépendances |
|----------|-------------|-------------|
| `deploy_all` | Orchestration complète | pipeline_cd + cluster-postgres |
| `pipeline_cd` | Harbor + K3s + ArgoCD | VMs harbor, k3s-manager, k3s-worker |
| `cluster-postgres` | PostgreSQL Master + Replica | VMs postgres-master, postgres-replica |
| `deploy_dns` | Serveur DNS Bind9 | VM dns |
| `deploy_reverse_proxy` | Reverse Proxy (Traefik/Nginx) | VM reverse-proxy |
| `deploy_wikijs` | WikiJS | VM wikijs |
| `deploy_snmp` | Monitoring SNMP | VM snmp |

## 🔧 Configuration

### Variables d'environnement (depuis `env.conf`)

```bash
# Répertoire Ansible (défaut: ./ansible)
ANSIBLE_DIR="./ansible"

# Inventaire (défaut: inventories/dev/hosts.yml)
ANSIBLE_INVENTORY="inventories/dev/hosts.yml"

# Fichier d'environnement (défaut: ./env.conf)
ENV_FILE="./env.conf"
```

### Structure attendue

```
iac-v3/
├── 6-deploiement-ansible.sh      # Ce script
├── env.conf                       # Configuration
└── ansible/
    ├── playbooks/
    │   ├── deploy_all.yml         # Orchestration
    │   ├── pipeline_cd.yml        # Harbor + K3s + ArgoCD
    │   ├── cluster-postgres.yml   # PostgreSQL
    │   └── ...
    └── inventories/
        └── dev/
            └── hosts.yml          # Inventaire
```

## 📤 Exemples de sortie

### Déploiement unique

```bash
$ ./6-deploiement-ansible.sh pipeline_cd

===============================================
  EXÉCUTION MULTIPLE - 1 PLAYBOOK(S)
===============================================

===============================================
  Exécution: pipeline_cd
===============================================
📋 Inventory: ./ansible/inventories/dev/hosts.yml
📋 Playbook: ./ansible/playbooks/pipeline_cd.yml

PLAY [Déploiement Pipeline CD] ...
...
✅ Playbook pipeline_cd exécuté avec succès

✅ Tous les playbooks ont été exécutés avec succès
```

### Déploiement multiple

```bash
$ ./6-deploiement-ansible.sh pipeline_cd cluster-postgres

===============================================
  EXÉCUTION MULTIPLE - 2 PLAYBOOK(S)
===============================================

===============================================
  Exécution: pipeline_cd
===============================================
...
✅ Playbook pipeline_cd exécuté avec succès

===============================================
  Exécution: cluster-postgres
===============================================
...
✅ Playbook cluster-postgres exécuté avec succès

✅ Tous les playbooks ont été exécutés avec succès
```

### Liste des playbooks

```bash
$ ./6-deploiement-ansible.sh -l

📋 Playbooks disponibles dans ./ansible/playbooks:
  - cluster-postgres.yml
  - deploy_all.yml
  - deploy_dns.yml
  - deploy_harbor.yml
  - deploy_k3s.yml
  - deploy_reverse_proxy.yml
  - deploy_snmp.yml
  - deploy_wikijs.yml
  - pipeline_cd.yml
```

### Syntax-check

```bash
$ ./6-deploiement-ansible.sh -c

🔍 Vérification syntaxique des playbooks...
  Checking cluster-postgres... OK
  Checking deploy_all... OK
  Checking deploy_dns... OK
  ...
```

## 📝 Notes

- **Idempotence** : Les playbooks peuvent être relancés sans effets de bord
- **SSH Keys** : Le script gère automatiquement les clés SSH (via `ansible_ssh_extra_args`)
- **Inventaire** : Utilise par défaut `inventories/dev/hosts.yml`
- **Variables** : Charge automatiquement `env.conf` si présent
- **Erreurs** : En mode multi-playbooks, continue sur erreur mais signale l'échec final

## 🔗 Intégration Pipeline

Ce script fait partie de la pipeline complète :

```
0-main.sh → 5-generate-terraform-config.sh → terraform apply
                                                      ↓
                                          6-deploiement-ansible.sh
                                                      ↓
                                          ansible/playbooks/deploy_all.yml
                                                      ↓
                                              Infrastructure prête
```

## 📚 Voir aussi

- [README-0.md](README-0.md) - Orchestration principale
- [README-5.md](README-5.md) - Génération config Terraform
- [ansible/playbooks/deploy_all.yml](ansible/playbooks/deploy_all.yml) - Orchestration Ansible
