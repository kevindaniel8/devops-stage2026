# Cluster PostgreSQL avec repmgr

Ce projet utilise **repmgr** pour gérer la réplication PostgreSQL de manière robuste et professionnelle.

## 🏗️ Architecture

- **Master**: 192.168.56.21 (postgres1)
- **Slave**: 192.168.56.22 (postgres2)
- **Port forwarding**: Master → 5433, Slave → 5434

## 🚀 Scripts disponibles

### 📦 Démarrage
- `./rebuild_cluster_repmgr.sh` - Recréation complète du cluster avec repmgr

### 🔧 Utilitaires
- `./monitor_cluster_repmgr.sh` - Monitoring du cluster repmgr
- `./failover_repmgr.sh` - Bascule manuelle avec repmgr

### 📁 Dossiers
- `postgres1/` - VM master
- `postgres2/` - VM slave
- `pas_fonctionnel/` - Anciens scripts archivés

## 🔑 Mots de passe par défaut

- **PostgreSQL**: `postgres`
- **Repmgr**: `repmgr_password`

Personnalisation:
```bash
export POSTGRES_PASSWORD=votre_mot_de_passe
export REPMGR_PASSWORD=votre_mot_de_passe_repmgr
./rebuild_cluster_repmgr.sh
```

## 🚀 Utilisation rapide

```bash
# Recréer le cluster complet
./rebuild_cluster_repmgr.sh

# Monitorer le cluster
./monitor_cluster_repmgr.sh

# Bascule manuelle (si besoin)
./failover_repmgr.sh
```

## ✅ Avantages de repmgr

- **Robuste**: Gère tous les cas d'erreur
- **Automatisé**: Configuration en quelques commandes
- **Monitoring**: État détaillé de la réplication
- **Failover**: Bascule automatique ou manuelle
- **Professionnel**: Standard de l'industrie

## 📊 Connexions DBeaver

**Master**:
- Host: 192.168.56.21
- Port: 5432
- User: postgres
- Password: postgres

**Slave**:
- Host: 192.168.56.22
- Port: 5432
- User: postgres
- Password: postgres

## 🔍 Vérification

Après le démarrage, vérifiez que la réplication fonctionne:

```bash
./monitor_cluster_repmgr.sh
```

Le monitoring doit afficher:
- ✅ Master en ligne
- ✅ Slave en mode recovery
- ✅ Réplication active
