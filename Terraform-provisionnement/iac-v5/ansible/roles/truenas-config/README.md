# TrueNAS Configuration Role

Ce rôle Ansible configure automatiquement un serveur TrueNAS (FreeBSD) pour l'infrastructure, incluant la création d'utilisateur admin, configuration ZFS, et partages NFS/SFTP.

## Fonctionnalités

- **Configuration utilisateur admin** : Création de l'utilisateur `truenas_admin` avec droits sudo
- **Configuration SSH** : Activation et configuration du service SSH
- **Configuration ZFS** : Création de pool et datasets ZFS
- **Partages NFS** : Configuration des exports NFS pour les réseaux autorisés
- **Configuration SFTP** : Configuration de l'accès SFTP avec chroot
- **Services** : Activation des services NFS, SSHD, et SFTP

## Prérequis

- TrueNAS/FreeBSD accessible via SSH
- Accès root sur le NAS
- Disques disponibles pour la création du pool ZFS (si nouveau pool)

## Variables Principales

### Configuration TrueNAS

```yaml
truenas_host: "192.168.20.8"
truenas_user: "root"
truenas_password: ""
```

### Configuration utilisateur admin

```yaml
truenas_admin_user: "truenas_admin"
truenas_admin_password: "admin"
truenas_admin_full_name: "TrueNAS Administrator"
truenas_admin_email: "admin@greencontracts.lan"
truenas_admin_groups: ["wheel"]
```

### Configuration SSH

```yaml
truenas_ssh_enabled: true
truenas_ssh_port: "22"
truenas_ssh_permit_root_login: "yes"
```

### Configuration ZFS Pool

```yaml
truenas_pool_name: "tank"
truenas_pool_disks:
  - "/dev/ada0"
  - "/dev/ada1"
truenas_pool_raid: "mirror"  # mirror, raidz1, raidz2, raidz3
```

### Configuration Datasets ZFS

```yaml
truenas_datasets:
  - name: "postgresql"
    path: "/mnt/tank/postgresql"
    compression: "lz4"
    atime: "off"
    sync: "standard"
  - name: "backups"
    path: "/mnt/tank/backups"
    compression: "lz4"
    atime: "off"
    sync: "standard"
  - name: "shared"
    path: "/mnt/tank/shared"
    compression: "lz4"
    atime: "off"
    sync: "standard"
```

### Configuration NFS

```yaml
truenas_nfs_enabled: true
truenas_nfs_shares:
  - name: "postgresql-backups"
    path: "/mnt/tank/postgresql"
    network: "192.168.20.0/24"
    ro: false
    maproot_user: "root"
    maproot_group: "wheel"
  - name: "shared-data"
    path: "/mnt/tank/shared"
    network: "192.168.20.0/24"
    ro: false
    maproot_user: "truenas_admin"
    maproot_group: "wheel"
```

### Configuration SFTP

```yaml
truenas_sftp_enabled: true
truenas_sftp_port: "22"
truenas_sftp_users:
  - username: "truenas_admin"
    home: "/mnt/tank/shared"
    chroot: true
```

## Utilisation

### Déploiement standard

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_truenas_config.yml
```

### Avec variables personnalisées

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_truenas_config.yml \
  -e "truenas_admin_password=mypassword" \
  -e "truenas_ssh_port=2222"
```

### Avec création de pool ZFS

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_truenas_config.yml \
  -e "truenas_pool_disks=['/dev/ada0','/dev/ada1']" \
  -e "truenas_pool_raid=mirror"
```

## Structure ZFS

Le rôle configure la structure ZFS suivante :

```
tank (pool)
├── postgresql (dataset)
│   └── /mnt/tank/postgresql
├── backups (dataset)
│   └── /mnt/tank/backups
└── shared (dataset)
    └── /mnt/tank/shared
```

## Partages NFS

Les partages NFS sont configurés dans `/etc/exports` :

```
/mnt/tank/postgresql 192.168.20.0/24 rw,maproot=root:wheel
/mnt/tank/shared 192.168.20.0/24 rw,maproot=truenas_admin:wheel
```

## Configuration SFTP

L'accès SFTP est configuré avec chroot pour les utilisateurs spécifiés :

- Utilisateur : `truenas_admin`
- Home : `/mnt/tank/shared`
- Chroot : Activé (limité à son home directory)
- Subsystem SFTP : Activé

## Dépannage

### Vérifier la connectivité SSH

```bash
ssh root@192.168.20.8 echo "NAS_OK"
```

### Vérifier l'utilisateur admin

```bash
ssh root@192.168.20.8 "id truenas_admin"
```

### Vérifier le pool ZFS

```bash
ssh root@192.168.20.8 "zpool list"
```

### Vérifier les datasets

```bash
ssh root@192.168.20.8 "zfs list"
```

### Vérifier les exports NFS

```bash
ssh root@192.168.20.8 "cat /etc/exports"
```

### Vérifier le service NFS

```bash
ssh root@192.168.20.8 "service nfsd status"
```

### Redémarrer le service NFS

```bash
ssh root@192.168.20.8 "service nfsd restart"
```

### Tester le montage NFS depuis un client

```bash
sudo mount -t nfs 192.168.20.8:/mnt/tank/postgresql /mnt/test
```

### Tester l'accès SFTP

```bash
sftp truenas_admin@192.168.20.8
```

## Notes importantes

1. **SSH doit être activé** : Le rôle nécessite que SSH soit activé sur TrueNAS avant le déploiement
2. **Pool ZFS existant** : Si un pool ZFS existe déjà, le rôle ne créera pas de nouveau pool
3. **Disques** : La création de pool ZFS nécessite des disques spécifiés dans `truenas_pool_disks`
4. **Mot de passe** : Le mot de passe par défaut est "admin", il doit être changé en production
5. **Permissions** : Le rôle configure l'utilisateur admin avec les droits sudo
6. **Chroot SFTP** : Les utilisateurs SFTP sont limités à leur home directory pour la sécurité

## Sécurité

- Le mot de passe root doit être configuré dans `truenas_password` ou via Ansible Vault
- Le mot de passe admin par défaut est "admin", il doit être changé
- SSH root login peut être désactivé via `truenas_ssh_permit_root_login: "no"`
- Les clés SSH sont recommandées pour l'authentification

## Personnalisation

Pour ajouter de nouveaux datasets NFS ou SFTP, modifier les variables dans `defaults/main.yml` :

```yaml
truenas_datasets:
  - name: "mon-dataset"
    path: "/mnt/tank/mon-dataset"
    compression: "lz4"
    atime: "off"
    sync: "standard"

truenas_nfs_shares:
  - name: "mon-partage"
    path: "/mnt/tank/mon-dataset"
    network: "192.168.20.0/24"
    ro: false
    maproot_user: "truenas_admin"
    maproot_group: "wheel"
```

## Architecture

```
TrueNAS (192.168.20.8)
├── Utilisateur admin : truenas_admin
├── SSH : Activé (port 22)
├── ZFS Pool : tank
│   ├── postgresql
│   ├── backups
│   └── shared
├── NFS : Activé
│   ├── /mnt/tank/postgresql → 192.168.20.0/24
│   └── /mnt/tank/shared → 192.168.20.0/24
└── SFTP : Activé
    └── truenas_admin → /mnt/tank/shared (chroot)
```

## Intégration avec PostgreSQL Backup

Ce rôle configure le NAS pour recevoir les sauvegardes PostgreSQL :

- Dataset `/mnt/tank/postgresql` pour les sauvegardes PostgreSQL
- Export NFS vers le réseau 192.168.20.0/24
- L'utilisateur `truenas_admin` a les droits nécessaires

Le rôle `postgres-backup` peut être configuré pour utiliser ce NAS :
```yaml
postgres_backup_nas_enabled: true
postgres_backup_nas_host: "192.168.20.8"
postgres_backup_nas_path: "/mnt/tank/postgresql"
```
