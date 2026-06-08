# 📋 Documentation Infrastructure - Mini IaC/IaaS

> **Architecture** : `Firewall` → `AD/DNS` → `Services` → `Database` → `Kubernetes` → `CI/CD`
> 
> **Note** : Certaines machines peuvent être supprimées ou éteintes selon les besoins (notamment la machine de management).

---

## 🌐 Réseau

| Paramètre | Valeur |
|-----------|--------|
| **Gateway** | 192.168.20.1 |
| **DNS Server** | 192.168.20.2 |
| **Subnet** | 192.168.20.0/24 |
| **VMID Start** | 200 |

---

## 🖥️ Tableau des VMs

| # | Nom VM | IP | Description | **DEV** (Minimum) | | | **PROD** (Recommandé) | | |
|---|--------|-----|-------------|:---:|:---:|:---:|:---:|:---:|:---:|
| | | | | **CPU** | **RAM** | **Disk** | **CPU** | **RAM** | **Disk** |
| 1 | **firewall-opnsense** | .1 | Firewall / Gateway OPNsense | 2 | 3 Go | 20 Go | 4 | 4 Go | 20 Go |
| 2 | **machine-managemt** | .2 | Machine de management / déploiement | 2¹ | 2 Go | 35 Go | 2¹ | 2 Go | 35 Go |
| 3 | **nas-truenas** | .3 | Stockage NAS (NFS/SMB) | 2 | 4 Go | 50 Go | 4 | 8 Go | 100 Go |
| 4 | **ad-dns-samba** | .5 | Active Directory + DNS interne | 2 | 3 Go | 20 Go | 4 | 4 Go | 30 Go |
| 5 | **smtp-mailserver** | .8 | Serveur email complet | 2 | 4 Go | 30 Go | 4 | 6 Go | 50 Go |
| 6 | **db-postgres-master** | .20 | PostgreSQL Master | 2 | 4 Go | 30 Go | 4 | 8 Go | 50 Go |
| 7 | **db-postgres-replication** | .21 | PostgreSQL Réplication + Backup | 2 | 4 Go | 30 Go | 4 | 8 Go | 100 Go |
| 8 | **nextcloud** | .10 | Cloud auto-hébergé | 2 | 4 Go | 50 Go | 4 | 8 Go | 100 Go |
| 9 | **reverse-proxy** | .200 | Nginx Reverse Proxy SSL | 2 | 2 Go | 15 Go | 4 | 4 Go | 20 Go |
| 10 | **cicd-runner** | .201 | CI/CD Runner (GitHub/Jenkins) | 4 | 8 Go | 40 Go | 8 | 16 Go | 80 Go |
| 11 | **harbor-registry** | .205 | Registry Docker privé | 2 | 4 Go | 100 Go | 4 | 8 Go | 200 Go |
| 12 | **loadbalancer-k8s** | .210 | HAProxy/MetalLB K8s | 2 | 2 Go | 15 Go | 2 | 4 Go | 20 Go |
| 13 | **k8s-master** | .220 | Kubernetes Control Plane | 2 | 4 Go | 30 Go | 4 | 8 Go | 50 Go |
| 14 | **k8s-worker1** | .221 | Kubernetes Worker Node #1 | 4 | 8 Go | 50 Go | 8 | 16 Go | 100 Go |
| 15 | **k8s-worker2** | .222 | Kubernetes Worker Node #2 | 4 | 8 Go | 50 Go | 8 | 16 Go | 100 Go |

> ¹ La machine de management utilise `sockets=2, cores=1` (total 2 vCPU). En production, garder cette config minimale car elle peut être éteinte.

---

## 📊 Totaux des Ressources

| Environnement | **vCPU** | **RAM** | **Stockage** |
|---------------|:--------:|:-------:|:------------:|
| **DEV** (Minimum) | **36** | **60 Go** | **535 Go** |
| **PROD** (Recommandé) | **68** | **118 Go** | **955 Go** |

### 📈 Évolution DEV → PROD

| Métrique | DEV | PROD | Augmentation |
|----------|:---:|:----:|:------------:|
| **vCPU** | 36 | 68 | +89% |
| **RAM** | 60 Go | 118 Go | +97% |
| **Stockage** | 535 Go | 955 Go | +78% |

---

## 💡 Recommandations par Environnement

### 🧪 Mode Développement (DEV)

Configuration minimale pour tester l'infrastructure sur un seul serveur Proxmox.

**Machines critiques** (toujours actives) :
- `firewall-opnsense` - Point d'entrée obligatoire
- `ad-dns-samba` - Authentification et DNS
- `nas-truenas` - Stockage partagé
- `db-postgres-master` - Base de données
- `k8s-master` + `k8s-worker1` - Kubernetes minimal
- `reverse-proxy` - Accès aux services

**Machines optionnelles** (peuvent être éteintes) :
- `machine-managemt` - Uniquement pour déploiement/maintenance
- `db-postgres-replication` - Pas critique en DEV
- `k8s-worker2` - Un seul worker suffit en DEV
- `cicd-runner` - Optionnel si pas de builds fréquents

### 🏭 Mode Production (PROD)

Configuration recommandée pour un environnement stable avec redondance.

**Points clés** :
- **Doubler les Workers K8s** : 8 cœurs / 16 Go RAM pour supporter les workloads
- **Harbor** : 200 Go de stockage pour les images Docker et les scans
- **DB Replica** : 100 Go pour les backups complets
- **Nextcloud** : 100 Go pour les fichiers utilisateurs
- **NAS** : 100 Go pour les volumes partagés K8s

---

## 🔧 Notes Techniques

### ⚠️ Conflits d'IP potentiels

- L'IP `192.168.20.1` est utilisée par le **firewall** mais est aussi le **gateway par défaut**.
  - Soit changer l'IP du firewall en `.254`
  - Soit utiliser une autre subnet (ex: `192.168.30.0/24`)

### ⚠️ Service de messagerie (Mailcow vs Modoboa)

**Solution actuelle : Mailcow Dockerized**
- Mailcow est utilisé comme serveur de messagerie complet
- Déployé via Docker Compose sur la VM `smtp-mailserver` (.8)
- Interface web d'administration intégrée
- Stockage des emails local (sur la VM)

**Solution idéale (non implémentée) : Modoboa**
- Pour des raisons de maintenance et d'intégration, Modoboa aurait été préférable :
  - Intégration LDAP native avec AD/DNS Samba
  - Base de données PostgreSQL 16 standardisée
  - Stockage des emails sur TrueNAS via NFS
  - Architecture plus modulaire et maintenable

**Pourquoi Mailcow ?**
- Difficulté à dockeriser Modoboa correctement dans l'infrastructure actuelle
- Mailcow fournit une solution "tout-en-un" fonctionnelle immédiatement
- Permet de déployer rapidement un serveur de messagerie complet
- Peut être remplacé par Modoboa ultérieurement si une solution de conteneurisation est trouvée

### 🔄 Ordre de démarrage recommandé

```
1. firewall-opnsense    (Infrastructure réseau)
2. ad-dns-samba          (Authentification)
3. nas-truenas           (Stockage)
4. db-postgres-master    (Base de données)
5. db-postgres-replication (Réplication)
6. k8s-master            (Orchestration)
7. k8s-worker1/2         (Workloads)
8. reverse-proxy         ( exposition)
9. nextcloud, mail, etc. (Services applicatifs)
10. cicd-runner          (CI/CD - optionnel)
```

### 💾 Disques importants

| VM | Disk DEV | Disk PROD | Raison |
|----|----------|-----------|--------|
| **harbor-registry** | 100 Go | 200 Go | Images Docker + scans de vulnérabilités |
| **nextcloud** | 50 Go | 100 Go | Fichiers utilisateurs |
| **nas-truenas** | 50 Go | 100 Go | Volumes NFS pour K8s |
| **db-postgres-replication** | 30 Go | 100 Go | Backup complet + WAL |
| **k8s-worker1/2** | 50 Go | 100 Go | Container images + volumes éphémères |

---

## 🚀 Commandes Utiles

### Déployer toute l'infrastructure
```bash
cd /home/kevin/devops-stage2026/Terraform-provisionnement/iac-v3
cp vm-definitions-infra.json vm-definitions.json
./0-main.sh
```

### Déployer uniquement les VMs critiques (DEV)
```bash
# Éditer vm-definitions.json pour commenter les VMs optionnelles
nano vm-definitions.json
./5-generate-terraform-config.sh
cd Terraform && terraform apply
```

### Éteindre les machines non critiques
```bash
ssh root@192.168.0.1 "qm stop 202 && qm stop 221 && qm stop 201"
# machine-managemt, k8s-worker2, cicd-runner
```

---

*Généré automatiquement depuis `vm-definitions-infra.json`*
