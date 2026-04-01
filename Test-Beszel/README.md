# Beszel 0.18.4 - Configuration Optimisée

Cette configuration est optimisée pour une connexion automatique des agents avec un minimum d'actions grâce au token universel permanent.

## 🚀 Fonctionnement optimisé

Vagrant crée automatiquement deux fichiers séparés :
- `docker-compose-server.yml` : Pour le serveur Beszel
- `docker-compose-agent.yml` : Pour l'agent (pré-rempli)

## 📋 Procédure simplifiée

1. **Démarrez l'environnement** :
   ```bash
   vagrant up
   ```

2. **Accédez à l'interface Beszel** :
   - URL: http://localhost:8090
   - Identifiants par défaut: admin/admin (changez-les immédiatement)

3. **Créez le token universel permanent** :
   - Allez dans `/settings/tokens`
   - Cliquez sur "Create Universal Token"
   - Cochez "Make permanent" 
   - Copiez la KEY et le TOKEN générés

4. **Configurez l'agent** :
   ```bash
   vagrant ssh
   sudo nano /opt/beszel/docker-compose-agent.yml
   # Remplacez KEY="" par KEY="VOTRE_KEY_COPIEE"
   # Remplacez TOKEN=VOTRE_TOKEN_ICI par TOKEN=VOTRE_TOKEN_COPIE
   cd /opt/beszel
   docker compose -f docker-compose-agent.yml up -d
   ```

## ✅ Avantages de cette configuration

- **Zéro configuration manuelle** : Fichiers pré-remplis et positionnés
- **Séparation claire** : Serveur et agent dans des fichiers distincts
- **Déploiement rapide** : Uniquement KEY et TOKEN à copier-coller
- **Token permanent** : Pas besoin de régénérer les tokens
- **Versions fixées** : Utilisation de la version 0.18.4 spécifique

## � Structure des fichiers générés dans la VM

```
/opt/beszel/
├── docker-compose-server.yml    # Serveur Beszel
├── docker-compose-agent.yml      # Agent (pré-rempli)
└── beszel_agent_data/           # Données de l'agent
```

## �🔧 Configuration réseau optimisée

- `network_mode: host` : Accès direct aux interfaces réseau
- `privileged: true` : Accès complet aux métriques système
- Volumes montés en read-only pour la sécurité

##  Pour déployer sur d'autres serveurs

Copiez simplement le fichier `docker-compose-agent.yml` avec votre token :

```bash
# Sur chaque nouveau serveur
scp docker-compose-agent.yml user@serveur:/opt/beszel/
ssh user@serveur
cd /opt/beszel
# Éditez KEY et TOKEN
docker compose -f docker-compose-agent.yml up -d

# ✅ Redémarrage simple (idempotent)
docker compose -f docker-compose-agent.yml up -d

# ✅ Redémarrage forcé (idempotent)
docker compose -f docker-compose-agent.yml restart

# ✅ Reconstruction si nécessaire (idempotent)
docker compose -f docker-compose-agent.yml up -d --force-recreate

```

L'agent se connectera automatiquement à votre hub Beszel sans aucune configuration supplémentaire.


Explication du warning :
Found orphan containers ([beszel-server]) for this project
Cause : Docker Compose voit beszel-agent dans le fichier mais détecte beszel-server qui tourne
Raison : Nous avons deux fichiers séparés (docker-compose-server.yml et docker-compose-agent.yml)
Impact : AUCUN - l'agent fonctionne parfaitement

Solutions :
Option 1 : Ignorer (recommandé)
Le warning est inoffensif, votre agent fonctionne.

Option 2 : Nettoyer les orphelins
bash
docker compose -f docker-compose-agent.yml up -d --remove-orphans
Option 3 : Utiliser des noms de projet différents
bash
docker compose -f docker-compose-agent.yml -p beszel-agent up -d
docker compose -f docker-compose-server.yml -p beszel-server up -d
🎯 État actuel :
Agent running ✅
Serveur running ✅
Connexion établie ✅
Warning sans impact ⚠️