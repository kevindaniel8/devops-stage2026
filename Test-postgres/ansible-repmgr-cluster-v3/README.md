# Cluster PostgreSQL repmgr V3

## 🎯 Objectifs V3

- **Une seule commande** : `vagrant up`
- **Pas de VM temporaire** : Provisionnement depuis l'hôte
- **Robustesse maximale** : Basé sur V2 robuste
- **Simplicité** : Déploiement automatisé

## 🚀 Déploiement

### Option 1: Script simple (recommandé)
```bash
./scripts/deploy_simple.sh
```

### Option 2: Manuel
```bash
# 1. Créer les VMs
vagrant up master replica --provision

# 2. Configurer repmgr depuis l'hôte
ansible-playbook -i inventory/production.ini playbooks/deploy_cluster_robuste.yml
```

### Option 3: VM temporaire (si nécessaire)
```bash
# Créer les VMs
vagrant up master replica --no-provision

# Configurer avec VM temporaire
vagrant up provision_final
```

## 📊 Architecture

```
Hôte (Vagrant)                VMs VirtualBox
├── master (192.168.56.21)  ──┐
│   PostgreSQL 16             │
│   repmgr                    │
├── replica (192.168.56.22)  ──┼──> Réplication
│   PostgreSQL 16             │
│   repmgr                    │
└── ansible-playbook          ──┘
    (depuis l'hôte)
```

## 🔧 Améliorations V3

1. **Provisionnement direct** : ansible_local depuis l'hôte
2. **Pas de VM cluster_setup** : Économie de ressources
3. **Scripts simplifiés** : Une seule commande
4. **Robustesse héritée** : Basé sur V2 fonctionnelle
5. **Monitoring intégré** : Vérifications automatiques

## 📱 Connexions

- **Master** : `192.168.56.21:5432` (postgres/postgres)
- **Replica** : `192.168.56.22:5432` (postgres/postgres)

## 🔧 Tests et monitoring

```bash
# Test du cluster
./scripts/test_cluster.sh

# Bascule manuelle
./scripts/failover.sh

# Monitoring cluster
vagrant ssh master -c 'sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show'
```

## 🎯 Avantages V3

- ✅ **Une seule commande** : `./scripts/deploy_simple.sh`
- ✅ **Pas de VM temporaire** : Moins de ressources
- ✅ **Provisionnement hôte** : Plus rapide et fiable
- ✅ **Robustesse V2** : Retries et vérifications
- ✅ **Simplicité** : Scripts automatisés
