# Configuration des Alertes Beszel

Guide complet pour créer des alertes sur PostgreSQL et les conteneurs Docker.

---

## 🚨 Types d'Alertes Disponibles dans Beszel

Beszel permet de créer des alertes pour :

- **CPU** : Utilisation processeur
- **Mémoire (RAM)** : Utilisation mémoire
- **Disque** : Espace disque disponible
- **Bande passante** : Trafic réseau
- **Température** : Température CPU/capteurs
- **Load Average** : Charge système
- **Status** : État du système (online/offline)
- **Docker** : État des conteneurs

---

## 📧 Configuration des Notifications

### Étape 1 : Configurer le canal de notification

Dans l'interface Beszel :
1. Allez dans **Settings > Notifications**
2. Choisissez votre canal (email, Slack, Discord, Telegram, etc.)

#### Exemples de configuration Shoutrrr :

**Email (SMTP)** :
```
smtp://username:password@host:port/?fromAddress=sender@example.com&toAddresses=recipient@example.com
```

**Slack** :
```
slack://token@channel
```

**Discord** :
```
discord://token@channel
```

**Telegram** :
```
telegram://token@chatid
```

---

## 🐘 Alertes pour PostgreSQL

### Alerte 1 : Service PostgreSQL Down

**Objectif** : Être alerté si le service PostgreSQL s'arrête

**Configuration** :
1. Allez sur **PostgreSQL-Server** dans Beszel
2. Cliquez sur **Alerts**
3. Ajoutez une alerte **Status**
4. Définissez : **Trigger when = Down**

**Message d'alerte** :
```
🚨 CRITIQUE : PostgreSQL est DOWN sur {{ .System.Name }}
Service : postgresql
Statut : {{ .Alert.Status }}
Temps : {{ .Alert.Time }}
```

---

### Alerte 2 : CPU PostgreSQL Trop Élevé

**Objectif** : Surveiller la charge CPU du processus PostgreSQL

**Configuration** :
1. Allez sur **PostgreSQL-Server**
2. **Alerts > Add Alert**
3. Type : **CPU**
4. Condition : **Above 80% for 5 minutes**

**Message** :
```
⚠️ ALERTE : CPU élevé sur PostgreSQL
Système : {{ .System.Name }}
CPU : {{ .Alert.Value }}%
Seuil : 80%
```

---

### Alerte 3 : Mémoire PostgreSQL

**Configuration** :
1. Type : **Memory**
2. Condition : **Above 85% for 5 minutes**

**Message** :
```
⚠️ ALERTE : Mémoire saturée sur PostgreSQL
Système : {{ .System.Name }}
RAM : {{ .Alert.Value }}%
```

---

### Alerte 4 : Espace Disque Data PostgreSQL

**Configuration** :
1. Type : **Disk**
2. Mount Point : `/var/lib/postgresql`
3. Condition : **Above 90%**

**Message** :
```
🚨 CRITIQUE : Espace disque PostgreSQL critique
Système : {{ .System.Name }}
Disque : {{ .Alert.Value }}% utilisé
Libérez de l'espace immédiatement !
```

---

### Alerte 5 : Trop de Connexions PostgreSQL

**Objectif** : Surveiller le nombre de connexions actives

**Méthode** : Utiliser le script de health check avec une alerte personnalisée

**Configuration avancée** :
```bash
# Créez un check personnalisé qui retourne un code d'erreur
# si les connexions dépassent un seuil
```

---

## 🐳 Alertes pour les Conteneurs Docker

### Alerte 1 : Conteneur Docker Arrêté

**Configuration** :
1. Allez sur votre système (Beszel-Hub ou PostgreSQL-Server)
2. **Alerts > Add Alert**
3. Type : **Docker Container Status**
4. Container : `beszel-agent` (ou autre conteneur critique)
5. Condition : **Not running**

**Message** :
```
🚨 CRITIQUE : Conteneur Docker arrêté
Système : {{ .System.Name }}
Conteneur : {{ .Alert.ContainerName }}
Statut : {{ .Alert.Status }}
Action nécessaire : docker compose up -d
```

---

### Alerte 2 : CPU Élevé sur un Conteneur

**Configuration** :
1. Type : **Docker Container CPU**
2. Container : Nom du conteneur
3. Condition : **Above 90% for 5 minutes**

**Message** :
```
⚠️ ALERTE : CPU élevé sur conteneur Docker
Système : {{ .System.Name }}
Conteneur : {{ .Alert.ContainerName }}
CPU : {{ .Alert.Value }}%
```

---

### Alerte 3 : Mémoire Conteneur Critique

**Configuration** :
1. Type : **Docker Container Memory**
2. Condition : **Above 1GB for 10 minutes**

**Message** :
```
⚠️ ALERTE : Mémoire conteneur élevée
Système : {{ .System.Name }}
Conteneur : {{ .Alert.ContainerName }}
Mémoire : {{ .Alert.Value }}
```

---

### Alerte 4 : Redémarrages Fréquents d'un Conteneur

**Configuration** :
1. Type : **Docker Container Restarts**
2. Condition : **Above 5 in 1 hour**

**Message** :
```
⚠️ ALERTE : Conteneur instable
Système : {{ .System.Name }}
Conteneur : {{ .Alert.ContainerName }}
Redémarrages : {{ .Alert.Value }} en 1 heure
Vérifiez les logs : docker logs {{ .Alert.ContainerName }}
```

---

## 🎯 Configuration Recommandée pour Votre Setup

### Sur PostgreSQL-Server (192.168.56.22) :

| Alerte | Type | Seuil | Priorité |
|--------|------|-------|----------|
| PostgreSQL Down | Status | Down | CRITIQUE |
| CPU Élevé | CPU | > 80% | WARNING |
| RAM Saturée | Memory | > 85% | WARNING |
| Disque Critique | Disk | > 90% | CRITIQUE |
| Beszel Agent Down | Docker Status | Not running | CRITIQUE |

### Sur Beszel-Hub (192.168.56.13) :

| Alerte | Type | Seuil | Priorité |
|--------|------|-------|----------|
| Hub Down | Status | Down | CRITIQUE |
| CPU Élevé | CPU | > 90% | WARNING |
| Disque Plein | Disk | > 85% | WARNING |
| Beszel Server Down | Docker Status | Not running | CRITIQUE |

---

## 📱 Exemples de Messages d'Alerte Personnalisés

### Template complet pour alerte système :
```
🚨 ALERTE BESZEL

Système : {{ .System.Name }}
Type : {{ .Alert.Type }}
Statut : {{ .Alert.Status }}
Valeur : {{ .Alert.Value }}
Seuil : {{ .Alert.Threshold }}

Heure : {{ .Alert.Time }}
Description : {{ .Alert.Description }}

🔗 Lien : http://192.168.56.13:8090/system/{{ .System.ID }}
```

### Pour Slack/Discord (format Markdown) :
```
**🚨 Alerte Beszel - {{ .System.Name }}**

• **Type** : {{ .Alert.Type }}
• **Statut** : {{ .Alert.Status }}
• **Valeur** : {{ .Alert.Value }}
• **Seuil** : {{ .Alert.Threshold }}

⏰ {{ .Alert.Time }}

[Voir dans Beszel](http://192.168.56.13:8090/system/{{ .System.ID }})
```

---

## 🔧 Scripts d'Automatisation des Alertes

### Script pour vérifier l'état des alertes :
```bash
#!/bin/bash
# check-alerts.sh - À exécuter régulièrement via cron

# Vérifie si Beszel répond
if ! curl -s http://192.168.56.13:8090/api/health > /dev/null; then
    echo "CRITIQUE : Beszel Hub ne répond pas !"
    # Envoyer une alerte externe (email, SMS, etc.)
fi

# Vérifie si PostgreSQL répond
if ! pg_isready -h 192.168.56.22 -p 5432 -q; then
    echo "CRITIQUE : PostgreSQL ne répond pas !"
fi
```

---

## 📋 Checklist de Mise en Place

- [ ] Configurer canal de notification (email/Slack/Discord)
- [ ] Créer alerte "PostgreSQL Down" sur PostgreSQL-Server
- [ ] Créer alerte "CPU > 80%" sur PostgreSQL-Server
- [ ] Créer alerte "Disk > 90%" sur PostgreSQL-Server
- [ ] Créer alerte "Beszel Agent Down" sur PostgreSQL-Server
- [ ] Créer alerte "Beszel Server Down" sur Beszel-Hub
- [ ] Tester les alertes (arrêter volontairement un service)
- [ ] Vérifier la réception des notifications
- [ ] Documenter les procédures de réponse aux alertes

---

## 🚀 Prochaines Étapes Avancées

1. **Alertes conditionnelles** : Dépendant de l'heure (hors heures de bureau)
2. **Escalade** : Si pas de réponse après X minutes, alerter le manager
3. **Auto-réparation** : Scripts qui tentent de redémarrer les services automatiquement
4. **Dashboard dédié** : Vue spéciale pour les alertes critiques

Vos systèmes sont maintenant protégés avec des alertes intelligentes ! 🎯
