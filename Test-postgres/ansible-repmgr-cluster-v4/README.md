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
Master (192.168.56.21)    Replica (192.168.56.22)    NewServer (192.168.56.23)
     │                           │                           │
     └─────────┬─────────────────┘                           │
               │                                         │
         Cluster repmgr                            Nouvelle replica
               │                                         │
         Auto-promotion                             Auto-reconstruction
```

## 🔧 Améliorations V4

1. **Provisionnement direct** : ansible_local depuis l'hôte
2. **Pas de VM cluster_setup** : Économie de ressources
3. **Scripts simplifiés** : Une seule commande
4. **Robustesse héritée** : Basé sur V2 fonctionnelle
5. **Monitoring intégré** : Vérifications automatiques

## � Monitoring et récupération

```bash
# Lancer le monitoring
./scripts/monitor_cluster.sh
```

### Fonctionnalités du script de monitoring :

1. **Test Master** : Vérifie si le master est en ligne
2. **Test Replica** : Vérifie si la replica est en ligne
3. **Auto-promotion** : Si master down, promeut la replica en master
4. **Auto-reconstruction** : Si replica down, crée une nouvelle replica

## � Tests manuels

```bash
# Vérifier le statut du cluster
vagrant ssh master -c 'sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf cluster show'

# Vérifier la réplication
vagrant ssh master -c 'sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"'

# Test de bascule manuelle
vagrant ssh replica -c 'sudo -u postgres repmgr -f /etc/repmgr/16/repmgr.conf standby promote'
```

## 🔄 Scénarios de récupération

### 1. Master DOWN
- Détection : Le monitoring détecte que le master ne répond plus
- Action : Promotion automatique de la replica en master
- Résultat : La replica devient le nouveau master primaire

### 2. Replica DOWN
- Détection : Le monitoring détecte que la replica ne répond plus
- Action : Création automatique d'une nouvelle VM replica
- Résultat : Nouvelle replica configurée et connectée au master

## 📱 Connexions

- **Master** : `192.168.56.21:5432` (postgres/postgres)
- **Replica** : `192.168.56.22:5432` (postgres/postgres)
- **NewServer** : `192.168.56.23:5432` (postgres/postgres)

## 🛠️ Scripts disponibles

- `deploy_v4.sh` : Déploiement complet du cluster
- `monitor_cluster.sh` : Monitoring et auto-récupération
- `test_cluster.sh` : Tests de fonctionnement du cluster

## 🎯 Avantages V4

- ✅ **Une seule commande** : `./scripts/deploy_v4.sh`
- ✅ **Pas de VM temporaire** : Moins de ressources
- ✅ **Provisionnement hôte** : Plus rapide et fiable
- ✅ **Robustesse V2** : Retries et vérifications
- ✅ **Simplicité** : Scripts automatisés
