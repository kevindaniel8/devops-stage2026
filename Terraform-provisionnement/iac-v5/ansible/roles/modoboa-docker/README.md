# Rôle Modoboa Docker

Ce rôle Ansible déploie Modoboa (solution de messagerie web) avec Docker, intégré à l'infrastructure existante.

## Architecture

Modoboa est configuré pour s'intégrer avec les composants de l'infrastructure :

- **PostgreSQL 16** : Base de données sur `db-postgres-master` (192.168.20.20)
- **LDAP** : Intégration avec AD/DNS Samba (192.168.20.5)
- **Stockage NFS** : Emails stockés sur TrueNAS (192.168.20.3)

## Variables

Les variables principales sont définies dans `defaults/main.yml` :

```yaml
modoboa_domain: "mail.greencontracts.lan"
modoboa_install_dir: "/opt/modoboa-docker"
modoboa_http_port: 8080
modoboa_https_port: 8443

# PostgreSQL 16
modoboa_db_host: "192.168.20.20"
modoboa_db_port: 5432
modoboa_db_name: "modoboa"
modoboa_db_user: "modoboa"
modoboa_db_password: "{{ vault_modoboa_db_password }}"

# LDAP (AD/DNS Samba)
modoboa_ldap_enabled: true
modoboa_ldap_server: "ldap://192.168.20.5"
modoboa_ldap_bind_dn: "cn=admin,dc=greencontracts,dc=lan"
modoboa_ldap_bind_password: "{{ vault_ldap_bind_password }}"
modoboa_ldap_base_dn: "dc=greencontracts,dc=lan"

# Stockage NFS (TrueNAS)
modoboa_nfs_enabled: true
modoboa_nfs_server: "192.168.20.3"
modoboa_nfs_path: "/mnt/truenas/mail/modoboa"
modoboa_nfs_mount_point: "/mnt/modoboa"

# Nettoyage
modoboa_cleanup: false
force_reinstall: false
```

## Prérequis

- Rôle `docker` (installation de Docker)
- PostgreSQL 16 déployé sur `db-postgres-master`
- AD/DNS Samba déployé et configuré
- TrueNAS avec partage NFS configuré
- Base de données PostgreSQL créée pour Modoboa

## Utilisation

Déploiement normal :
```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_modoboa-docker.yml
```

Déploiement avec nettoyage complet (supprime conteneurs, volumes, répertoire et images) :
```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_modoboa-docker.yml --tags cleanup -e modoboa_cleanup=true
```

## Configuration LDAP

Modoboa est configuré pour utiliser LDAP comme backend d'authentification :

- **Serveur LDAP** : ldap://192.168.20.5
- **Base DN** : dc=greencontracts,dc=lan
- **Utilisateurs** : ou=users,dc=greencontracts,dc=lan
- **Groupes** : ou=groups,dc=greencontracts,dc=lan

Les utilisateurs sont synchronisés depuis l'AD/DNS Samba.

## Configuration PostgreSQL

Modoboa utilise PostgreSQL 16 comme base de données :

- **Hôte** : 192.168.20.20
- **Port** : 5432
- **Base de données** : modoboa
- **Utilisateur** : modoboa

La base de données doit être créée manuellement avant le déploiement :
```sql
CREATE DATABASE modoboa;
CREATE USER modoboa WITH PASSWORD 'votre_mot_de_passe';
GRANT ALL PRIVILEGES ON DATABASE modoboa TO modoboa;
```

## Stockage NFS

Les emails sont stockés sur TrueNAS via NFS :

- **Serveur NFS** : 192.168.20.3
- **Chemin NFS** : /mnt/truenas/mail/modoboa
- **Point de montage** : /mnt/modoboa

Le partage NFS doit être configuré sur TrueNAS avec les permissions appropriées.

## Ports

- HTTP : 8080
- HTTPS : 8443 (si SSL activé)
- IMAP : 143 (Dovecot)
- IMAPS : 993 (Dovecot, si SSL activé)
- SMTP : 25 (Postfix)

## Accès

- **Interface web** : http://192.168.20.8:8080
- **Admin** : admin
- **Mot de passe** : Défini via `modoboa_admin_password`

## Idempotence

Le rôle est partiellement idempotent :
- Le déploiement Docker Compose est idempotent
- Le montage NFS est idempotent
- La création de l'administrateur doit être gérée manuellement

Pour un redéploiement complet propre, utilisez le tag `cleanup` :
```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_modoboa-docker.yml --tags cleanup -e modoboa_cleanup=true
```

Le nettoyage complet supprime :
- Les conteneurs modoboa
- Les volumes Docker
- Le répertoire modoboa
- Les images Docker modoboa

## Structure

- `tasks/main.yml` : Tâches de déploiement
- `defaults/main.yml` : Variables par défaut
- `templates/docker-compose.yml.j2` : Template Docker Compose
- `templates/settings.py.j2` : Template de configuration Modoboa

## Avantages par rapport à Mailcow

- Intégration LDAP native avec AD/DNS Samba
- Base de données PostgreSQL 16 standardisée
- Stockage des emails sur TrueNAS via NFS
- Architecture plus modulaire et maintenable
- Meilleure intégration avec l'infrastructure existante

## Limitations

- Nécessite une configuration LDAP fonctionnelle
- Nécessite un partage NFS configuré sur TrueNAS
- Plus complexe à déployer que Mailcow
- Nécessite la création manuelle de la base de données PostgreSQL
