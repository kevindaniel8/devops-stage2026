# Surveillance PostgreSQL avec Beszel

## 🌐 Architecture : PostgreSQL sur VM distante

**Votre setup** :
- **Hub Beszel** : 192.168.56.13 
- **Base PostgreSQL** : 192.168.56.22

## 🔍 Options de surveillance

### Option 1 : Agent Beszel sur VM PostgreSQL (Recommandé)
Déployez un agent directement sur la VM PostgreSQL pour une surveillance locale et précise.

#### Étapes de déploiement sur 192.168.56.22 :

1. **Copiez les fichiers** :
```bash
# Depuis votre machine locale
scp docker-compose-agent-remote.yml user@192.168.56.22:/opt/beszel/docker-compose-agent-remote.yml
scp postgres-health.sh user@192.168.56.22:/opt/beszel/postgres-health.sh
ssh user@192.168.56.22 "chmod +x /opt/beszel/postgres-health.sh"
```

2. **Configurez l'agent pour votre hub** :
```bash
ssh user@192.168.56.22
sudo nano /opt/beszel/docker-compose-agent-remote.yml
# Modifiez SERVER="http://192.168.56.13:8090"
# Modifiez TOKEN avec votre token universel permanent
```

3. **Démarrez l'agent** :
```bash
cd /opt/beszel
docker compose -f docker-compose-agent-remote.yml up -d
```

#### Ce que vous surveillerez :
- **Service PostgreSQL** (systemd) : état, CPU, mémoire, redémarrages
- **Processus PostgreSQL** : utilisation CPU/RAM détaillée  
- **I/O disque** : lectures/écritures générées par PostgreSQL
- **Réseau** : connexions sur le port 5432
- **Espace disque** : data directories PostgreSQL

---

### Option 2 : Monitoring réseau depuis hub Beszel
Surveillance basique via le réseau depuis votre VM Beszel actuelle.

#### Configuration sur 192.168.56.13 :
```bash
# Test de connectivité
pg_isready -h 192.168.56.22 -p 5432

# Test de requête
psql -h 192.168.56.22 -p 5432 -U postgres -c "SELECT version();"
```

#### Limites :
- ❌ Pas de monitoring du service systemd
- ❌ Pas de métriques CPU/mémoire du processus
- ❌ Pas d'accès aux logs locaux
- ✅ Uniquement connectivité et requêtes SQL

---

## 🎯 Configuration recommandée (Option 1)

### Fichiers créés pour vous :

1. **`docker-compose-agent-remote.yml`** : Configuration agent pour VM PostgreSQL
2. **`postgres-health.sh`** : Script de health check détaillé
3. **Noms personnalisés** : `SYSTEM_NAME` pour identifier facilement chaque système

### Variables d'environnement à configurer :

Dans `docker-compose-agent-remote.yml` sur 192.168.56.22 :
```yaml
environment:
  SERVER: "http://192.168.56.13:8090"  # URL de votre hub Beszel
  TOKEN: "VOTRE_TOKEN_UNIVERSEL"      # Token de votre hub
  SYSTEM_NAME: "PostgreSQL-Server"      # 🏷️ NOM PERSONNALISÉ
  POSTGRES_HOST: "localhost"          # PostgreSQL local
  POSTGRES_PORT: "5432"
  POSTGRES_USER: "postgres"
  POSTGRES_DB: "postgres"
  POSTGRES_PASSWORD: "votre_password"  # Si nécessaire
```

Dans `docker-compose-agent.yml` sur 192.168.56.13 (votre hub) :
```yaml
environment:
  SYSTEM_NAME: "Beszel-Hub"          # 🏷️ NOM PERSONNALISÉ pour le hub
  # ... autres variables
```

### Avantages des noms personnalisés :

✅ **Identification facile** : Plus besoin de deviner qui fait quoi
- `Beszel-Hub` : Votre serveur de monitoring
- `PostgreSQL-Server` : Votre base de données
- `Web-Server-1` : Pour un serveur web
- `Database-Master` : Pour une base de données principale

✅ **Organisation claire** : Dans l'interface Beszel, vous verrez :
- **Beszel-Hub** (192.168.56.13)
- **PostgreSQL-Server** (192.168.56.22)

✅ **Recherche rapide** : Trouvez instantanément le système qui vous intéresse

### Script de health check personnalisé :

Le script `postgres-health.sh` vérifie :
- ✅ Connectivité PostgreSQL
- ✅ Exécution de requêtes
- ✅ Nombre de connexions actives
- ✅ Taille de la base de données

---

## 📊 Métriques disponibles dans Beszel

### Depuis la VM PostgreSQL (192.168.56.22) :

**Section "Services"** :
- `postgresql.service` : État, CPU, mémoire, redémarrages
- `docker.service` : Si PostgreSQL en container

**Section "Overview"** :
- Charge système générée par PostgreSQL
- Mémoire utilisée par le processus
- I/O disque (lectures/écritures)

**Section "Storage"** :
- Espace utilisé par `/var/lib/postgresql/`
- I/O operations

**Section "Network"** :
- Connexions entrantes sur port 5432
- Traffic réseau PostgreSQL

---

## 🔧 Déploiement pas à pas

### Étape 1 : Préparation VM PostgreSQL
```bash
# Sur 192.168.56.22
sudo apt update && sudo apt install -y postgresql-client
mkdir -p /opt/beszel
```

### Étape 2 : Déploiement de l'agent
```bash
# Copie des fichiers
scp docker-compose-agent-remote.yml postgres-health.sh user@192.168.56.22:/opt/beszel/

# Configuration
ssh user@192.168.56.22
cd /opt/beszel
chmod +x postgres-health.sh
sudo nano docker-compose-agent-remote.yml  # Adapter SERVER et TOKEN
docker compose -f docker-compose-agent-remote.yml up -d
```

### Étape 3 : Vérification dans Beszel
1. Allez sur http://192.168.56.13:8090
2. Vous devriez voir 2 systèmes :
   - `beszel-vm` (votre hub)
   - La VM PostgreSQL (nouvel agent)
3. Cliquez sur la VM PostgreSQL pour voir les métriques

---

## � Avantages de cette configuration

- **Surveillance locale** : Métriques précises du processus PostgreSQL
- **Service systemd** : État complet du service PostgreSQL
- **Logs accessibles** : Surveillance des logs PostgreSQL
- **Alertes** : Notification si PostgreSQL tombe
- **Historique** : Graphiques d'évolution des performances

Votre PostgreSQL distant sera maintenant surveillé en temps réel depuis votre hub Beszel ! 🎯
