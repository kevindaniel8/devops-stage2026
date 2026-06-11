# README - Scripts 9 et 9a : Configuration Firewall OPNsense

## 📋 Description

Ce dossier contient deux scripts pour automatiser la configuration du firewall OPNsense :

- **9a-generate-firewall-api-keys.sh** : Génération automatique des clés API OPNsense via SSH
- **9-configure-firewall.sh** : Configuration du firewall OPNsense via API (alias, règles, NAT)

## 🎯 Objectif

Automatiser la création des clés d'authentification API et la configuration complète du firewall OPNsense pour l'infrastructure.

## 📁 Fichiers concernés

| Fichier | Description |
|---------|-------------|
| `9a-generate-firewall-api-keys.sh` | Script de génération des clés API |
| `9-configure-firewall.sh` | Script de configuration du firewall via API |
| `ssh/opnsense-conf-co.txt` | Fichier stockant les clés générées (créé automatiquement) |
| `env.conf` | Configuration définissant le chemin du fichier de clés et paramètres firewall |
| `firewall-config/` | Répertoire d'export de configuration (généré automatiquement) |

## 🔧 Configuration dans env.conf

```bash
# Chemin du fichier de stockage des clés API
FIREWALL_API_KEYS_FILE="${SCRIPT_DIR}/ssh/opnsense-conf-co.txt"

# IP du firewall OPNsense
FIREWALL_WAN_IP="192.168.0.50"
FIREWALL_LAN_IP="192.168.20.1"

# Interfaces firewall
FIREWALL_WAN_IF="wan"
FIREWALL_LAN_IF="lan"

# Clés API (générées par 9a-generate-firewall-api-keys.sh)
FIREWALL_API_KEY=""
FIREWALL_API_SECRET=""
```

## 🚀 Utilisation

### 1. Prérequis

- Clé SSH autorisée sur OPNsense (root)
- OPNsense accessible en SSH sur `FIREWALL_WAN_IP`

### 2. Lancer la génération

```bash
cd /home/kevin/devops-stage2026/Terraform-provisionnement/iac-v5
./9a-generate-firewall-api-keys.sh
```

### 3. Vérifier les clés générées

```bash
cat ssh/opnsense-conf-co.txt
```

### 4. Utiliser les clés

Le script `9-configure-firewall.sh` charge automatiquement les clés depuis le fichier défini.

```bash
./9-configure-firewall.sh check    # Test API
./9-configure-firewall.sh routing  # Configurer routage SSH
./9-configure-firewall.sh all      # Tout configurer
```

---

## 🔥 Script 9-configure-firewall.sh

### 📋 Description

Ce script configure automatiquement le firewall OPNsense via l'API REST. Il permet de créer des alias réseau, des règles de filtrage, des règles de routage inter-VLAN et des règles NAT.

### 🎯 Fonctionnalités

- **Alias réseau** : Création d'alias pour les groupes de machines et réseaux
- **Règles LAN** : Configuration des règles de filtrage interne
- **Routage inter-VLAN** : Autorisation du trafic entre réseaux (dev → infra)
- **NAT** : Configuration du port forwarding vers les services exposés
- **Export** : Génération de fichiers CSV pour import manuel

### 📁 Alias configurés

| Alias | Type | Contenu | Description |
|-------|------|---------|-------------|
| INFRA_MGMT | host | 192.168.20.2 | Station de management |
| DEV_NETWORK | network | 192.168.0.0/24 | Réseau de développement |
| INFRA_DATABASE | host | 192.168.20.20 192.168.20.21 | Serveurs PostgreSQL |
| INFRA_K8S_CONTROL | host | 192.168.20.220 | K3s Control Plane |
| INFRA_K8S_WORKERS | host | 192.168.20.221 192.168.20.222 | K3s Workers |
| INFRA_K8S_ALL | network | 192.168.20.220/29 | Tous les nœuds K3s |
| INFRA_ALL_SERVERS | network | 192.168.20.0/24 | Toute l'infrastructure |
| INFRA_NAS | host | 192.168.20.5 | NAS TrueNAS |
| INFRA_NEXTCLOUD | host | 192.168.20.10 | Nextcloud |
| INFRA_REVERSE_PROXY | host | 192.168.20.3 | Reverse Proxy |
| INFRA_HARBOR | host | 192.168.20.205 | Harbor Registry |
| INFRA_WIKIJS | host | 192.168.20.4 | WikiJS |
| INFRA_OPENPROJECT | host | 192.168.20.4 | OpenProject |
| INFRA_MAILSERVER | host | 192.168.20.3 | Mailserver |

### 🔧 Commandes disponibles

```bash
./9-configure-firewall.sh check      # Vérifier la connexion API
./9-configure-firewall.sh aliases    # Créer uniquement les alias
./9-configure-firewall.sh rules      # Créer uniquement les règles LAN
./9-configure-firewall.sh routing    # Créer les règles de routage inter-VLAN
./9-configure-firewall.sh nat        # Créer uniquement les règles NAT
./9-configure-firewall.sh export     # Exporter la configuration (CSV)
./9-configure-firewall.sh all        # Exécuter tout (aliases + rules + routing + nat)
./9-configure-firewall.sh help       # Afficher l'aide
```

### 📝 Règles LAN configurées

| Source | Destination | Protocole | Port | Description |
|--------|-------------|-----------|------|-------------|
| INFRA_MGMT | INFRA_ALL_SERVERS | any | any | Management → All |
| INFRA_ALL_SERVERS | INFRA_ALL_SERVERS | tcp | 22 | SSH interne |
| INFRA_K8S_ALL | INFRA_DATABASE | tcp | 5432 | K8s → PostgreSQL |
| INFRA_DATABASE | INFRA_DATABASE | tcp | 5432 | Replication PG |
| INFRA_K8S_ALL | INFRA_K8S_ALL | any | any | K8s inter-node |
| INFRA_ALL_SERVERS | INFRA_NAS | tcp | 2049,445 | NAS NFS/SMB |

### 🌐 Règles de routage inter-VLAN

| Source | Destination | Protocole | Port | Description |
|--------|-------------|-----------|------|-------------|
| DEV_NETWORK | INFRA_ALL_SERVERS | tcp | 22 | SSH depuis réseau dev |
| DEV_NETWORK | INFRA_ALL_SERVERS | icmp | any | Ping depuis réseau dev |
| DEV_NETWORK | INFRA_REVERSE_PROXY | tcp | 80,443 | HTTP/HTTPS vers Reverse Proxy |

### 🔀 Règles NAT configurées

| Protocole | Port externe | Destination interne | Port interne | Description |
|-----------|--------------|-------------------|-------------|-------------|
| tcp | 80 | 192.168.20.3 | 80 | HTTP → Reverse Proxy |
| tcp | 443 | 192.168.20.3 | 443 | HTTPS → Reverse Proxy |

### 📤 Export de configuration

Le script peut exporter la configuration en fichiers CSV pour import manuel :

```bash
./9-configure-firewall.sh export
```

Les fichiers sont générés dans `firewall-config/` :
- `aliases.csv` : Liste des alias réseau
- `rules.csv` : Liste des règles de filtrage

### ⚠️ Notes importantes

1. **Détection automatique** : Le script détecte s'il est exécuté sur OPNsense (localhost) ou à distance
2. **Idempotence** : Les commandes utilisent `|| true` pour éviter les erreurs de duplication
3. **Application** : Les changements sont appliqués automatiquement après chaque création
4. **IP cohérentes** : Les IP utilisées correspondent à l'inventaire actuel de l'infrastructure

### 🆘 Dépannage

#### Erreur de connexion API

```bash
# Vérifier les clés API
cat ssh/opnsense-conf-co.txt

# Tester la connexion API manuellement
curl -sk -u "KEY:SECRET" https://192.168.0.50/api/core/firmware/status
```

#### Alias non créés

```bash
# Vérifier les alias existants
ssh root@192.168.0.50 "opnsense-patch /tmp/aliases.conf"

# Recréer les alias
./9-configure-firewall.sh aliases
```

#### Règles non appliquées

```bash
# Vérifier les règles existantes
ssh root@192.168.0.50 "opnsense-patch /tmp/rules.conf"

# Forcer l'application
./9-configure-firewall.sh rules
```

### 🔧 Personnalisation

Pour ajouter de nouveaux alias ou règles, modifier directement le script `9-configure-firewall.sh` :

```bash
# Ajouter un alias
create_alias "MON_ALIAS" "host" "192.168.20.100"

# Ajouter une règle
create_rule "10" "INFRA_ALL_SERVERS" "MON_ALIAS" "tcp" "8080" "Mon service"
```

## 🔒 Sécurité

- **Permissions** : Le fichier `opnsense-conf-co.txt` est créé avec les permissions `600`
- **Localisation** : Le fichier est stocké dans `ssh/` (hors versionnement git)
- **Régénération** : Les clés peuvent être régénérées à tout moment en relançant le script

## 📝 Format du fichier de clés

```bash
# =============================================================================
# CONFIGURATION OPNsense - Clés API
# =============================================================================
# Généré le: 2026-01-01 12:00:00
# -----------------------------------------------------------------------------

FIREWALL_API_KEY="votre-cle-api-ici"
FIREWALL_API_SECRET="votre-secret-api-ici"
```

## 🔧 Changement d'emplacement

Pour stocker les clés ailleurs, modifier dans `env.conf` :

```bash
FIREWALL_API_KEYS_FILE="/chemin/vers/mon-fichier.txt"
```

Puis relancer la génération.

## ⚠️ Notes importantes

1. **Exécution sur OPNsense** : Si l'API n'est pas exposée sur WAN, le script doit être exécuté directement sur OPNsense (détection automatique via `127.0.0.1`)
2. **Clés multiples** : OPNsense supporte plusieurs clés API simultanément
3. **Révocation** : Les clés peuvent être révoquées via l'interface web OPNsense (System > Access > API)

## 🆘 Dépannage

### Connexion SSH échoue

```bash
# Tester la connexion SSH
ssh root@192.168.0.50 echo "OK"

# Si échec, copier la clé SSH
cat ~/.ssh/id_rsa.pub | ssh root@192.168.0.50 'cat >> ~/.ssh/authorized_keys'
```

### Génération échoue

- Vérifier que `configctl` existe sur OPNsense
- Vérifier les permissions sur `/conf/config.xml`

## 📚 Ressources

- [Documentation API OPNsense](https://docs.opnsense.org/development/api.html)
- Interface web : `https://192.168.0.50` → System > Access > API
