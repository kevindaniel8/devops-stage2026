# Rôle Ansible Mailcow

Ce rôle déploie Mailcow Dockerized, une suite de messagerie complète avec interface web d'administration.

## Informations de connexion

- **URL d'accès :** http://192.168.20.3:8080/admin
- **Utilisateur admin :** admin
- **Mot de passe admin :** moohoo À réinitialiser via le script `mailcow-reset-admin.sh` (voir section Réinitialisation du mot de passe)

## Variables

Les variables principales sont définies dans `defaults/main.yml` :

```yaml
mailcow_hostname: mail.greencontracts.lan
mailcow_http_port: 8080
mailcow_http_bind: "0.0.0.0"
mailcow_repo_dir: "/opt/mailcow-dockerized"
mailcow_timezone: "Europe/Paris"
mailcow_admin_password: "Admin123!"  # Non utilisé actuellement, voir section Réinitialisation
mailcow_cleanup: false  # Activer le nettoyage complet avant déploiement
force_reinstall: false  # Forcer la réinstallation complète
```

## Dépendances

- Rôle `docker` (installation de Docker)

## Utilisation

Déploiement normal :
```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_mailcow.yml
```

Déploiement via le playbook principal (Group1) :
```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_all.yml
```

Déploiement avec nettoyage complet (supprime conteneurs, volumes, répertoire et images) :
```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_mailcow.yml --tags cleanup -e mailcow_cleanup=true
```

Déploiement avec nettoyage complet et forçage de la réinstallation :
```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_mailcow.yml --tags cleanup -e mailcow_cleanup=true -e force_reinstall=true
```

## Réinitialisation du mot de passe admin

Le mot de passe admin doit être réinitialisé manuellement après le premier déploiement :

```bash
cd /opt/mailcow-dockerized
DBUSER=mailcow DBPASS=$(grep DBPASS .env | cut -d= -f2) DBNAME=mailcow bash helper-scripts/mailcow-reset-admin.sh -y
```

Le script affichera le nouveau mot de passe généré aléatoirement.

## Configuration automatique

Le rôle effectue automatiquement les corrections suivantes après le déploiement :

- Génération de certificats SSL auto-signés temporaires
- Configuration MySQL client pour désactiver SSL (ssl=0)
- Correction de la configuration nginx pour utiliser le port 9000 (au lieu de 9002)
- Redémarrage des conteneurs php-fpm et nginx

## Ports

- HTTP : 8080 (exposé sur 0.0.0.0)
- HTTPS : 8443 (exposé sur 0.0.0.0, utilisé en interne)
- MySQL : 13306 (exposé sur 127.0.0.1)

## Idempotence

Le rôle est partiellement idempotent :
- Le déploiement Docker Compose est idempotent
- Les corrections de configuration (nginx) sont appliquées uniquement si nécessaire
- Le premier déploiement nécessite une réinitialisation du mot de passe admin

Pour un redéploiement complet propre, utilisez le tag `cleanup` :
```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_mailcow.yml --tags cleanup -e mailcow_cleanup=true
```

Le nettoyage complet supprime :
- Les conteneurs mailcow
- Les volumes Docker
- Le répertoire mailcow
- Les images Docker mailcow

## Structure

- `tasks/main.yml` : Tâches de déploiement
- `defaults/main.yml` : Variables par défaut
- `templates/env.mailcow.j2` : Template du fichier .env
- `templates/mailcow.conf.j2` : Template du fichier mailcow.conf
