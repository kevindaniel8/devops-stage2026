# Connexion DBeaver au Cluster PostgreSQL

## 📋 Informations de connexion

### Connexion directe (depuis le réseau iac-v3)

| Paramètre | Valeur |
|-----------|--------|
| **Host** | `192.168.20.20` (master) ou `192.168.20.21` (replica) |
| **Port** | `5432` |
| **Database** | `postgres` (ou votre base applicative) |
| **User** | `postgres` |
| **Password** | `postgres_secure_password` |
| **SSL** | `Disabled` (ou `Prefer` si configuré) |

### Connexion via tunnel SSH (recommandé depuis l'extérieur)

| Paramètre | Valeur |
|-----------|--------|
| **Host** | `localhost` (après tunnel SSH) |
| **Port** | `5432` |
| **Database** | `postgres` |
| **User** | `postgres` |
| **Password** | `postgres_secure_password` |

**Configuration SSH Tunnel :**
| Paramètre | Valeur |
|-----------|--------|
| **SSH Host** | `192.168.20.20` (ou `192.168.20.21`) |
| **SSH Port** | `22` |
| **SSH Auth** | `Password` ou `Public Key` |
| **SSH User** | `ubuntu` |
| **SSH Password** | `ubuntu` (si auth par mot de passe) |
| **Private Key** | `~/.ssh/id_ed25519_terraform-proxmox` (si auth par clé) |

---

## 🔧 Configuration DBeaver étape par étape

### Méthode 1 : Connexion directe (si vous êtes sur le réseau 192.168.20.x)

1. **Ouvrir DBeaver** → `New Database Connection` (Ctrl+Shift+N)
2. **Sélectionner** : `PostgreSQL` → `Next`
3. **Onglet Main :**
   - Host: `192.168.20.20`
   - Port: `5432`
   - Database: `postgres`
   - User: `postgres`
   - Password: `postgres_secure_password`
4. **Test Connection** → `Finish`

### Méthode 2 : Tunnel SSH (recommandé pour plus de sécurité)

1. **Ouvrir DBeaver** → `New Database Connection`
2. **Sélectionner** : `PostgreSQL` → `Next`
3. **Onglet Main :**
   - Host: `localhost` (important !)
   - Port: `5432`
   - Database: `postgres`
   - User: `postgres`
   - Password: `postgres_secure_password`
4. **Onglet SSH :**
   - ✅ `Use SSH Tunnel`
   - Host/IP: `192.168.20.20`
   - Port: `22`
   - Authentication: `Password` ou `Public Key`
   - Username: `ubuntu`
   - Password: `ubuntu` (si Password auth)
   - **OU** Private Key: sélectionnez votre clé `id_ed25519_terraform-proxmox`
5. **Test Connection** → `Finish`

---

## 🧪 Test de connexion avec psql

### Test depuis votre machine (si PostgreSQL client installé)

```bash
# Test direct
psql -h 192.168.20.20 -p 5432 -U postgres -d postgres

# Test avec tunnel SSH
ssh -L 15432:localhost:5432 -i ~/.ssh/id_ed25519_terraform-proxmox ubuntu@192.168.20.20 -N
# Dans un autre terminal :
psql -h localhost -p 15432 -U postgres -d postgres
```

### Test depuis les VMs

```bash
# Test interne
ssh -i ~/.ssh/id_ed25519_terraform-proxmox ubuntu@192.168.20.20
sudo -u postgres psql -c "SELECT version();"
```

---

## 🔍 Vérification du serveur

Si la connexion échoue, vérifiez :

### 1. PostgreSQL écoute sur toutes les interfaces

```bash
ssh -i ~/.ssh/id_ed25519_terraform-proxmox ubuntu@192.168.20.20 \
  "sudo -u postgres psql -c 'SHOW listen_addresses;'"
# Doit retourner : *
```

### 2. pg_hba.conf autorise les connexions

```bash
ssh -i ~/.ssh/id_ed25519_terraform-proxmox ubuntu@192.168.20.20 \
  "sudo grep -E '^host' /etc/postgresql/16/main/pg_hba.conf"
# Doit contenir : host all all 192.168.20.0/24 md5
```

### 3. SSH est accessible

```bash
ssh -i ~/.ssh/id_ed25519_terraform-proxmox ubuntu@192.168.20.20 "echo OK"
```

### 4. Ports ouverts

```bash
ssh -i ~/.ssh/id_ed25519_terraform-proxmox ubuntu@192.168.20.20 \
  "sudo ss -tlnp | grep -E '5432|22'"
```

---

## ⚠️ Problèmes courants et solutions

### Erreur : "Could not verify `ssh-ed25519` host key" (SSH Tunnel)

**Cause :** Les VMs ont été recréées et leurs clés SSH ont changé. DBeaver/SSHJ détecte une différence avec `~/.ssh/known_hosts`.

**Solutions :**

**Solution 1 - Nettoyer les clés connues (rapide) :**
```bash
# Supprimer les anciennes clés SSH
ssh-keygen -f ~/.ssh/known_hosts -R 192.168.20.20
ssh-keygen -f ~/.ssh/known_hosts -R 192.168.20.21

# Se reconnecter manuellement pour accepter les nouvelles clés
ssh -i ~/.ssh/id_ed25519_terraform-proxmox ubuntu@192.168.20.20
# Tape "yes" quand demandé
```

**Solution 2 - Utiliser JSch au lieu de SSHJ (recommandé pour dev) :**
1. DBeaver → Éditer la connexion → **SSH**
2. Changer **"Implementation"** : `SSHJ` → `JSch`
3. JSch est moins strict sur les changements de clés host

**Solution 3 - Désactiver la vérification (⚠️ dev uniquement) :**
```bash
# Dans ~/.ssh/config
Host 192.168.20.*
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

**Pourquoi ça arrive ?**  
Les VMs Terraform/Proxmox génèrent de nouvelles clés SSH à chaque création. C'est normal en environnement dev où les VMs sont recréées souvent. En production, utilisez des clés SSH fixes.

---

### Erreur : "Connection refused"

**Cause :** PostgreSQL n'écoute pas sur l'interface réseau
**Solution :**
```bash
# Vérifier listen_addresses
ssh -i ~/.ssh/id_ed25519_terraform-proxmox ubuntu@192.168.20.20 \
  "sudo sed -i \"s/#listen_addresses = 'localhost'/listen_addresses = '*'/\" /etc/postgresql/16/main/postgresql.conf"

# Redémarrer PostgreSQL
ssh -i ~/.ssh/id_ed25519_terraform-proxmox ubuntu@192.168.20.20 \
  "sudo systemctl restart postgresql@16-main"
```

### Erreur : "FATAL: password authentication failed"

**Cause :** Mauvais mot de passe ou auth mal configurée
**Solution :** Vérifiez le mot de passe dans `group_vars/all.yml` :
```yaml
postgres_password: postgres_secure_password
```

### Erreur : "FATAL: no pg_hba.conf entry"

**Cause :** Connexion non autorisée dans pg_hba.conf
**Solution :** Vérifier que `pg_hba.conf` contient :
```
host all all 192.168.20.0/24 md5
```

### Erreur SSH : "Connection timed out"

**Cause :** VM inaccessible ou SSH down
**Solution :**
```bash
# Vérifier VM
ping 192.168.20.20

# Vérifier SSH
ssh -i ~/.ssh/id_ed25519_terraform-proxmox ubuntu@192.168.20.20 "sudo systemctl status ssh"
```

### Erreur : "Permission denied (publickey,password)"

**Cause :** Clé SSH incorrecte ou mot de passe SSH faux
**Solution :**
```bash
# Vérifier la clé
ls -la ~/.ssh/id_ed25519_terraform-proxmox

# Tester SSH
ssh -i ~/.ssh/id_ed25519_terraform-proxmox ubuntu@192.168.20.20
```

---

## 🔐 Sécurité

### Bonnes pratiques

1. **Utilisez toujours le tunnel SSH** pour les connexions externes
2. **Changez les mots de passe** par défaut en production
3. **Limitez l'accès réseau** au sous-réseau nécessaire
4. **Activez SSL** si nécessaire :
   - DBeaver → SSL tab → ✅ `Use SSL`
   - SSL Mode: `verify-ca` ou `require`

### Mots de passe actuels (dev)

| Utilisateur | Mot de passe | Usage |
|-------------|--------------|-------|
| `postgres` | `postgres_secure_password` | Administration |
| `repmgr` | `repmgr_secure_password` | Réplication |
| `ubuntu` (SSH) | `ubuntu` | Accès SSH |

**⚠️ Changez ces mots de passe en production !**

---

## 📞 Support

Si la connexion continue à échouer après ces vérifications :

1. **Testez le ping :** `ping 192.168.20.20`
2. **Testez SSH :** `ssh ubuntu@192.168.20.20`
3. **Vérifiez logs PostgreSQL :**
   ```bash
   ssh ubuntu@192.168.20.20 "sudo tail -20 /var/log/postgresql/postgresql-16-main.log"
   ```
4. **Vérifiez connexion locale :**
   ```bash
   ssh ubuntu@192.168.20.20 "sudo -u postgres psql -c 'SELECT 1;'"
   ```
