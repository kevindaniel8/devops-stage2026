# Scripts de gestion du Cluster PostgreSQL repmgr - iac-v3

Ce dossier contient les scripts de gestion et de monitoring du cluster PostgreSQL avec réplication repmgr pour l'environnement **iac-v3** (VMs Terraform/Proxmox).

## 📁 Structure

```
script_cluster_db/
├── README.md                          # Ce fichier
├── deploy_iac-v3.sh                   # Déploiement initial du cluster
├── test_iac-v3.sh                     # Tests complets du cluster
├── monitor_iac-v3.sh                  # Monitoring du cluster
├── failover_iac-v3.sh                 # Bascule manuelle (failover)
├── auto_failover_iac-v3.sh            # Bascule automatique
├── cluster_manager_iac-v3.sh          # Menu interactif complet
├── test_recreate_replica_iac-v3.sh    # Recréation de la replica
│
└── (scripts originaux Vagrant - conservés pour référence)
    ├── deploy_simple.sh
    ├── failover.sh
    ├── monitor_cluster.sh
    └── ...
```

## 🔧 Configuration

Les scripts utilisent les variables suivantes (modifiables) :

| Variable | Défaut | Description |
|----------|--------|-------------|
| `MASTER_IP` | `192.168.20.20` | IP du master PostgreSQL |
| `REPLICA_IP` | `192.168.20.21` | IP de la replica PostgreSQL |
| `SSH_KEY` | `~/.ssh/id_ed25519_terraform-proxmox` | Clé SSH pour connexion |
| `POSTGRES_PASSWORD` | `postgres_secure_password` | Mot de passe postgres |
| `REPMGR_PASSWORD` | `repmgr_secure_password` | Mot de passe repmgr |

## 🚀 Scripts principaux

### 1. Déploiement initial

```bash
./deploy_iac-v3.sh
```

**Fonction :**
- Vérifie la connectivité SSH aux VMs
- Déploie PostgreSQL + repmgr via Ansible
- Configure le cluster avec master et replica
- Affiche les informations de connexion

**Prérequis :** VMs démarrées via Terraform

---

### 2. Tests complets

```bash
./test_iac-v3.sh
```

**Fonction :**
- Test connectivité SSH
- Statut repmgr cluster
- Vérification PostgreSQL (version)
- Statut réplication (streaming)
- Test écriture/lecture réplication

---

### 3. Monitoring

```bash
./monitor_iac-v3.sh
```

**Fonction :**
- Vérifie l'état des deux nœuds
- Affiche le rôle de chaque nœud (master/replica)
- Test la réplication active
- Résumé du statut du cluster

---

### 4. Bascule manuelle (Failover)

```bash
./failover_iac-v3.sh
```

**Fonction :**
- Affiche l'état actuel du cluster
- Promouvoir la replica en master
- Affiche le nouveau statut
- Donne les instructions pour reconfigurer l'ancien master

**⚠️ Attention :** À utiliser quand le master est down ou pour maintenance.

---

### 5. Bascule automatique

```bash
./auto_failover_iac-v3.sh
```

**Fonction :**
- Vérifie la santé des nœuds (pg_isready)
- Si master down + replica OK → promotion automatique
- Si les deux down → alerte critique
- Si replica down → suggère recréation

---

### 6. Menu interactif (Gestion complète)

```bash
./cluster_manager_iac-v3.sh
```

Menu interactif avec options :
1. Statut du cluster
2. Test master
3. Test replica
4. Bascule manuelle
5. Monitoring complet
6. Test réplication
7. Quitter

**Commandes directes :**
```bash
./cluster_manager_iac-v3.sh status       # Statut cluster
./cluster_manager_iac-v3.sh test-master   # Test master
./cluster_manager_iac-v3.sh test-replica  # Test replica
./cluster_manager_iac-v3.sh promote       # Promouvoir replica
./cluster_manager_iac-v3.sh monitor       # Monitoring
./cluster_manager_iac-v3.sh test          # Tests complets
```

---

### 7. Recréation de la replica

```bash
./test_recreate_replica_iac-v3.sh
```

**Fonction :**
- Arrête PostgreSQL sur replica
- Nettoie les données existantes
- Clone depuis le master
- Redémarre PostgreSQL
- Enregistre comme standby

**⚠️ Usage :** Quand la replica est corrompue ou doit être reconstruite.

---

## 📊 Commandes Ansible utiles

```bash
cd /home/kevin/devops-stage2026/Terraform-provisionnement/iac-v3/ansible

# Statut du cluster
ansible -i inventories/dev/hosts.yml database -m shell \
  -a "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show" -b

# Vérifier PostgreSQL
ansible -i inventories/dev/hosts.yml database -m shell \
  -a "sudo -u postgres pg_isready" -b

# Statut réplication
ansible -i inventories/dev/hosts.yml db_master -m shell \
  -a "sudo -u postgres psql -c 'SELECT * FROM pg_stat_replication;'" -b

# Redéployer le cluster
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy-cluster-db.yml
```

---

## 🔌 Connexions

| Nœud | IP | Port | Utilisateur | Mot de passe |
|------|-----|------|-------------|--------------|
| Master | 192.168.20.20 | 5432 | postgres | postgres_secure_password |
| Replica | 192.168.20.21 | 5432 | postgres | postgres_secure_password |
| | | | repmgr | repmgr_secure_password |

**Exemple connexion :**
```bash
psql -h 192.168.20.20 -U postgres -d postgres
```

---

## ⚠️ Résolution des problèmes

### Problème : SSH host key changed

```bash
ssh-keygen -f ~/.ssh/known_hosts -R 192.168.20.20
ssh-keygen -f ~/.ssh/known_hosts -R 192.168.20.21
```

### Problème : Replica not streaming

```bash
# Vérifier statut
./monitor_iac-v3.sh

# Recréer la replica
./test_recreate_replica_iac-v3.sh
```

### Problème : Master down

```bash
# Bascule manuelle
./failover_iac-v3.sh

# Ou automatique
./auto_failover_iac-v3.sh
```

---

## 📝 Notes

- Les scripts utilisent **SSH clé** (pas de mot de passe SSH)
- Les VMs doivent être démarrées via **Terraform** avant utilisation
- Le rôle Ansible est dans `/ansible/roles/cluster-db/`
- Les variables sont dans `/ansible/group_vars/all.yml`

---

## 🆘 Support

En cas de problème majeur :
1. Vérifier VMs Terraform : `terraform show`
2. Tester SSH manuel : `ssh -i ~/.ssh/id_ed25519_terraform-proxmox ubuntu@192.168.20.20`
3. Logs PostgreSQL : `sudo journalctl -u postgresql@16-main -n 50`
4. Logs repmgr : `sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show`
