# README - Script 6a : Génération des clés API OPNsense

## 📋 Description

Ce script (`6a-generate-firewall-api-keys.sh`) génère automatiquement les clés API OPNsense via une connexion SSH sécurisée.

## 🎯 Objectif

Automatiser la création des clés d'authentification API nécessaires au script `6-configure-firewall.sh` pour configurer le firewall OPNsense.

## 📁 Fichiers concernés

| Fichier | Description |
|---------|-------------|
| `6a-generate-firewall-api-keys.sh` | Script de génération des clés |
| `6-configure-firewall.sh` | Script utilisant les clés pour configurer le firewall |
| `ssh/opnsense-conf-co.txt` | Fichier stockant les clés générées (créé automatiquement) |
| `env.conf` | Configuration définissant le chemin du fichier de clés |

## 🔧 Configuration dans env.conf

```bash
# Chemin du fichier de stockage des clés API
FIREWALL_API_KEYS_FILE="${SCRIPT_DIR}/ssh/opnsense-conf-co.txt"

# IP du firewall OPNsense
FIREWALL_WAN_IP="192.168.0.50"
FIREWALL_LAN_IP="192.168.20.1"
```

## 🚀 Utilisation

### 1. Prérequis

- Clé SSH autorisée sur OPNsense (root)
- OPNsense accessible en SSH sur `FIREWALL_WAN_IP`

### 2. Lancer la génération

```bash
cd /home/kevin/devops-stage2026/Terraform-provisionnement/iac-v3
./6a-generate-firewall-api-keys.sh
```

### 3. Vérifier les clés générées

```bash
cat ssh/opnsense-conf-co.txt
```

### 4. Utiliser les clés

Le script `6-configure-firewall.sh` charge automatiquement les clés depuis le fichier défini.

```bash
./6-configure-firewall.sh check    # Test API
./6-configure-firewall.sh routing  # Configurer routage SSH
./6-configure-firewall.sh all      # Tout configurer
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
