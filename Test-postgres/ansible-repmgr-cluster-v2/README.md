# Cluster PostgreSQL repmgr avec Ansible

Infrastructure PostgreSQL haute disponibilité avec repmgr et Ansible.

## 🏗️ Architecture

- **Master** : 192.168.56.21 - Nœud principal
- **Replica** : 192.168.56.22 - Nœud de réplication
- **Newserver** : 192.168.56.23 - Nœud de remplacement (créé uniquement en cas de défaillance)

## 📁 Structure

```
ansible-repmgr-cluster/
├── Vagrantfile              # Configuration VM (master + replica)
├── inventory/
│   └── production.ini       # Inventory Ansible
├── group_vars/
│   └── all.yml             # Variables globales
├── host_vars/
│   ├── master.yml          # Variables master
│   └── replica.yml         # Variables replica
├── roles/
│   ├── postgresql/         # Installation PostgreSQL
│   │   ├── tasks/main.yml
│   │   └── templates/pg_hba.conf.j2
│   └── repmgr/              # Configuration repmgr
│       ├── tasks/main.yml
│       └── templates/repmgr.conf.j2
├── playbooks/
│   └── deploy_cluster.yml  # Déploiement cluster
├── scripts/
│   ├── test_cluster.sh     # Tests du cluster
│   └── failover.sh         # Bascule manuelle
└── README.md               # Documentation
```

## 🚀 Utilisation

### 1. Déploiement complet (recommandé)

```bash
# Déploiement séquentiel complet
./scripts/deploy_all.sh
```

### 2. Déploiement manuel

```bash
# Étape 1: Création du master
vagrant up master

# Étape 2: Création du replica
vagrant up replica

# Étape 3: Configuration repmgr
vagrant up cluster_setup
```

### 3. Tests du cluster

```bash
# Test complet du cluster
./scripts/test_cluster.sh
```

### 4. Bascule manuelle

```bash
# Promotion du replica en master
./scripts/failover.sh
```

## 📱 Connexions

- **Master** : 192.168.56.21:5432 (postgres/postgres)
- **Replica** : 192.168.56.22:5432 (postgres/postgres)

## 🔧 Variables

- `POSTGRES_PASSWORD` : Mot de passe PostgreSQL (défaut: postgres)
- `REPMR_PASSWORD` : Mot de passe repmgr (défaut: repmgr_password)

## 📊 Monitoring

```bash
# Vérifier le statut du cluster
vagrant ssh master -c "sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show"

# Vérifier la réplication
vagrant ssh master -c "sudo -u postgres psql -c 'SELECT * FROM pg_stat_replication;'"
```

## 🚨 Défaillance

En cas de défaillance du master ou replica, le nœud `newserver` peut être déployé manuellement :

```bash
# Créer le nœud de remplacement
vagrant up newserver

# Configurer en fonction du nœud défaillant
ansible-playbook -i inventory/production.ini playbooks/deploy_cluster.yml --extra-vars "target_host=newserver"
```

## 🔄 Workflow de bascule

1. **Normal** : Master + Replica actif
2. **Master down** : Replica promu automatiquement
3. **Replica down** : Newserver peut être déployé
4. **Récupération** : Nœud défaillant réintégré comme replica

## 🧪 Tests

```bash
# Test de connectivité
./scripts/test_cluster.sh

# Test de bascule
./scripts/failover.sh

# Vérification post-bascule
./scripts/test_cluster.sh
```
