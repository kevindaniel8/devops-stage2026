# PostgreSQL Backup Role

Ce rôle Ansible automatise la sauvegarde de bases de données PostgreSQL avec un crontab à intervalle régulier paramétrable.

## Fonctionnalités

- **Sauvegarde automatique** : Dump logique des bases de données PostgreSQL
- **Crontab paramétrable** : Configuration de l'intervalle de sauvegarde via cron
- **Nom de fichier avec date/heure** : Format `{nom_base}_{YYYYMMDD-HHMMSS}.dump`
- **Compression** : Compression configurable des sauvegardes
- **Rétention** : Nettoyage automatique des anciennes sauvegardes
- **Copie vers NAS** : Transfert automatique vers le NAS (192.168.20.5)
- **Copie vers machine distante** : Optionnel, vers une IP définie en paramètre
- **Détection automatique des bases** : Liste automatique des bases existantes
- **Logging** : Logs détaillés pour le dépannage

## Prérequis

- PostgreSQL installé sur la cible
- Accès SSH vers le NAS (si activé)
- Accès SSH vers la machine distante (si activé)
- Permissions suffisantes pour créer des crontabs

## Variables Principales

### Configuration PostgreSQL

```yaml
postgres_backup_host: "localhost"
postgres_backup_port: "5432"
postgres_backup_user: "postgres"
postgres_backup_password: ""
```

### Configuration de sauvegarde

```yaml
postgres_backup_dir: "/var/backups/postgresql"
postgres_backup_retention_days: 7
postgres_backup_format: "custom"  # custom, plain, tar, directory
postgres_backup_compression: "9"  # 0-9
```

### Configuration Cron

```yaml
postgres_backup_cron_enabled: true
postgres_backup_cron_schedule: "0 2 * * *"  # Tous les jours à 2h
postgres_backup_cron_user: "postgres"
```

### Configuration NAS

```yaml
postgres_backup_nas_enabled: true
postgres_backup_nas_host: "192.168.20.5"
postgres_backup_nas_user: "ubuntu"
postgres_backup_nas_path: "/mnt/pool/postgresql-backups"
postgres_backup_nas_ssh_key: "~/.ssh/id_rsa"
```

### Configuration machine distante (optionnel)

```yaml
postgres_backup_remote_enabled: false
postgres_backup_remote_host: ""
postgres_backup_remote_user: "ubuntu"
postgres_backup_remote_path: "/var/backups/postgresql"
postgres_backup_remote_ssh_key: "~/.ssh/id_rsa"
```

### Sélection des bases de données

```yaml
# Vide = sauvegarde toutes les bases (sauf système)
postgres_backup_databases: []

# Ou spécifier les bases à sauvegarder
postgres_backup_databases:
  - myapp
  - nextcloud
  - moodle

# Bases à exclure (par défaut)
postgres_backup_exclude_databases:
  - "postgres"
  - "template0"
  - "template1"
```

## Utilisation

### Déploiement standard

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_postgres_backup.yml
```

### Avec variables personnalisées

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_postgres_backup.yml \
  -e "postgres_backup_cron_schedule='0 3 * * *'" \
  -e "postgres_backup_retention_days=14" \
  -e "postgres_backup_nas_enabled=true"
```

### Sauvegarder uniquement certaines bases

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_postgres_backup.yml \
  -e "postgres_backup_databases=['nextcloud','moodle']"
```

### Activer la copie vers une machine distante

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_postgres_backup.yml \
  -e "postgres_backup_remote_enabled=true" \
  -e "postgres_backup_remote_host=192.168.20.100"
```

## Format de sauvegarde

Le rôle supporte plusieurs formats de sauvegarde PostgreSQL :

- **custom** : Format compressé pg_dump (recommandé)
- **plain** : Format SQL texte
- **tar** : Archive tar compressée
- **directory** : Répertoire avec fichiers séparés

## Nom des fichiers de sauvegarde

Les fichiers de sauvegarde sont nommés selon le format :
```
{nom_base}_{YYYYMMDD-HHMMSS}.dump
```

Exemple :
```
nextcloud_20260611-020000.dump
moodle_20260611-020001.dump
```

## Emplacements de sauvegarde

### Local
- `/var/backups/postgresql/` sur le serveur PostgreSQL master

### NAS
- `/mnt/pool/postgresql-backups/` sur le NAS (192.168.20.5)

### Machine distante (optionnel)
- `/var/backups/postgresql/` sur la machine distante configurée

## Logs

Les logs sont stockés dans `/var/log/postgresql-backup/` avec le format :
```
postgres-backup-{YYYYMMDD-HHMMSS}.log
```

Les logs sont conservés pendant 30 jours par défaut.

## Dépannage

### Vérifier la connexion PostgreSQL

```bash
ssh ubuntu@192.168.20.20
sudo -u postgres psql -c "SELECT version();"
```

### Tester le script de sauvegarde manuellement

```bash
sudo -u postgres /usr/local/bin/postgres-backup.sh
```

### Vérifier les logs

```bash
sudo tail -f /var/log/postgresql-backup/postgres-backup-*.log
```

### Vérifier le crontab

```bash
sudo crontab -u postgres -l
```

### Vérifier la connectivité NAS

```bash
ssh -i ~/.ssh/id_rsa ubuntu@192.168.20.5 echo "NAS_OK"
```

### Restaurer une sauvegarde

```bash
# Depuis le format custom
pg_restore -h localhost -U postgres -d nextcloud /var/backups/postgresql/nextcloud_20260611-020000.dump

# Depuis le format plain
psql -h localhost -U postgres -d nextcloud < /var/backups/postgresql/nextcloud_20260611-020000.dump
```

## Sécurité

- Le script de sauvegarde utilise les variables d'environnement pour le mot de passe PostgreSQL
- Les clés SSH sont copiées avec les permissions 0600
- Les logs contiennent des informations sensibles, ils doivent être protégés
- Le mot de passe PostgreSQL ne doit pas être stocké en clair dans les variables Ansible (utiliser Ansible Vault)

## Personnalisation

Pour modifier le comportement du rôle, vous pouvez :

1. Modifier les variables dans `defaults/main.yml`
2. Passer des variables au moment du déploiement avec `-e`
3. Créer un fichier d'inventaire avec des variables spécifiques par hôte

## Notes importantes

1. Le rôle est déployé uniquement sur le master PostgreSQL (db-postgres-master)
2. Les sauvegardes sont effectuées sur le master uniquement
3. Le rôle détecte automatiquement les bases de données existantes
4. Les bases système (postgres, template0, template1) sont exclues par défaut
5. Le crontab peut être désactivé sans supprimer le script de sauvegarde
6. Les anciennes sauvegardes sont automatiquement supprimées après la période de rétention

## Architecture

```
db-postgres-master (192.168.20.20)
  └── /usr/local/bin/postgres-backup.sh (script de sauvegarde)
  └── /var/backups/postgresql/ (sauvegardes locales)
  └── /var/log/postgresql-backup/ (logs)
  └── crontab (exécution automatique)
      ├── NAS (192.168.20.5)
      │   └── /mnt/pool/postgresql-backups/
      └── Machine distante (optionnel)
          └── /var/backups/postgresql/
```
