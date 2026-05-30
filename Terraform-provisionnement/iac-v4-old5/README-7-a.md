# Distribution CA GreenContracts

Script de distribution de la CA interne GreenContracts aux clients pour permettre l'accès HTTPS aux services internes.

## Topologie réseau

- **192.168.20.0/24** : Réseau PVE (VMs : reverse-proxy, harbor, k3s-manager, pc-management)
- **192.168.0.0/24** : Réseau local box (PC de dev, futurs utilisateurs)

## Usage

```bash
./7-a-distribute-ca.sh [ssh|http|manual] [user@IP|hostname]
```

## Modes disponibles

### 1. Mode SSH (distribution automatique)

Distribution via SSH vers une cible spécifique.

**Syntaxe** :
```bash
./7-a-distribute-ca.sh ssh kevin@192.168.20.5
./7-a-distribute-ca.sh ssh 192.168.0.10
```

**Prérequis** :
- Accès SSH à la cible
- Droits sudo sur la cible

**Processus** :
1. Copie la CA via SCP vers `/tmp/greencontracts-ca.crt`
2. Crée le répertoire `/usr/local/share/ca-certificates` si nécessaire
3. Copie la CA dans le répertoire de destination
4. Met à jour le store de certificats avec `update-ca-certificates`
5. Nettoie le fichier temporaire

### 2. Mode HTTP (téléchargement)

Téléchargement depuis un serveur HTTP.

**Syntaxe** :
```bash
./7-a-distribute-ca.sh http https://ca.greencontracts.lan/ca.crt
```

**Prérequis** :
- Serveur HTTP configuré pour servir la CA
- Accès Internet ou intranet

**Processus** :
1. Télécharge la CA depuis l'URL spécifiée
2. Installe la CA dans `/usr/local/share/ca-certificates/`
3. Met à jour le store de certificats
4. Nettoie le fichier temporaire

### 3. Mode Manual (installation locale)

Installation locale sur la machine actuelle.

**Syntaxe** :
```bash
./7-a-distribute-ca.sh manual
```

**Processus** :
1. Copie la CA depuis `ansible/files/pki/ca/ca.crt`
2. Installe la CA dans `/usr/local/share/ca-certificates/`
3. Met à jour le store de certificats

## Exemples d'utilisation

### Installation sur pc-management (192.168.20.5)

```bash
./7-a-distribute-ca.sh ssh kevin@192.168.20.5
```

### Installation sur un PC du réseau box (192.168.0.0/24)

```bash
./7-a-distribute-ca.sh ssh 192.168.0.10
```

### Installation locale sur le PC de dev

```bash
./7-a-distribute-ca.sh manual
```

### Installation via HTTP (si serveur configuré)

```bash
./7-a-distribute-ca.sh http https://ca.greencontracts.lan/ca.crt
```

## Vérification de l'installation

Après installation, vérifier que la CA est bien installée :

```bash
# Vérifier la présence du fichier
ls -la /usr/local/share/ca-certificates/greencontracts-ca.crt

# Mettre à jour le store de certificats
sudo update-ca-certificates --fresh

# Vérifier que la CA est reconnue
openssl s_client -connect moodle.greencontracts.lan:443 -showcerts
```

## Dépannage

### Erreur "Fichier CA non trouvé"

Vérifier que le fichier CA existe :
```bash
ls -la ansible/files/pki/ca/ca.crt
```

### Erreur SSH "Permission denied"

Vérifier que :
- L'utilisateur a accès SSH à la cible
- L'utilisateur a les droits sudo sur la cible
- Le mot de passe sudo est correct

### Erreur HTTP "Failed to download"

Vérifier que :
- L'URL est accessible
- Le serveur HTTP est configuré correctement
- Le pare-feu ne bloque pas la connexion

## Architecture

Le script utilise le fichier CA situé dans :
```
ansible/files/pki/ca/ca.crt
```

La CA est installée dans :
```
/usr/local/share/ca-certificates/greencontracts-ca.crt
```

Le store de certificats est mis à jour via :
```bash
sudo update-ca-certificates
```

## Sécurité

- Le script nécessite des droits sudo pour installer la CA
- La CA interne ne doit être distribuée qu'aux machines de confiance
- Le mode SSH utilise scp pour le transfert sécurisé
- Le mode HTTP doit être utilisé uniquement sur des réseaux de confiance
