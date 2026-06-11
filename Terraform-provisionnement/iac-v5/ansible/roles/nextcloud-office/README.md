# Nextcloud Office Role

Ce rôle Ansible installe et configure Collabora Online (suite bureautique open source) pour Nextcloud.

## Fonctionnalités

- Installation de Collabora Online via Docker
- Installation des applications Nextcloud (richdocuments et richdocumentscode)
- Configuration automatique de l'intégration Nextcloud-Collabora
- Gestion des conteneurs Docker
- Configuration des ports et domaines

## Prérequis

- Nextcloud doit être installé (via snap)
- Docker doit être installé
- Accès root ou sudo

## Variables

### Variables principales

- `nextcloud_office_enabled`: Active/désactive le rôle (défaut: true)
- `nextcloud_office_collabora_enabled`: Active/désactive Collabora Online (défaut: true)
- `nextcloud_office_collabora_domain`: Domaine pour Collabora (défaut: reverse_proxy_domain)
- `nextcloud_office_collabora_port`: Port Collabora (défaut: "9980")
- `nextcloud_office_collabora_ssl`: Active SSL (défaut: true)
- `nextcloud_office_collabora_admin_user`: Utilisateur admin Collabora (défaut: "admin")
- `nextcloud_office_collabora_admin_password`: Mot de passe admin Collabora (défaut: "changeme")

### Applications Nextcloud

- `nextcloud_office_richdocuments_enabled`: Active l'app richdocuments (défaut: true)
- `nextcloud_office_richdocumentscode_enabled`: Active l'app richdocumentscode (défaut: true)

### Configuration Docker

- `nextcloud_office_docker_image`: Image Docker Collabora (défaut: "collabora/code")
- `nextcloud_office_docker_tag`: Tag de l'image (défaut: "latest")
- `nextcloud_office_container_name`: Nom du conteneur (défaut: "collabora-online")
- `nextcloud_office_data_dir`: Répertoire de données (défaut: "/opt/collabora")

## Utilisation

### Via playbook

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_nextcloud_office.yml
```

### Avec variables personnalisées

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_nextcloud_office.yml \
  -e "nextcloud_office_collabora_domain=mondomaine.lan" \
  -e "nextcloud_office_collabora_admin_password=motdepasse"
```

## Architecture

Le rôle effectue les étapes suivantes :

1. Vérifie que Nextcloud et Docker sont installés
2. Crée le répertoire de données Collabora
3. Arrête et supprime l'ancien conteneur si existant
4. Télécharge l'image Docker Collabora
5. Démarre le conteneur Collabora Online
6. Attend que le service soit prêt
7. Installe les applications Nextcloud (richdocuments, richdocumentscode)
8. Active les applications
9. Configure l'intégration Nextcloud-Collabora
10. Redémarre Nextcloud si nécessaire

## Services

- **Collabora Online** : Suite bureautique en ligne (éditeur de documents, tableurs, présentations)
- **richdocuments** : Application Nextcloud pour Collabora
- **richdocumentscode** : Application Nextcloud pour Collabora Code

## Ports

- **9980** : Port par défaut de Collabora Online

## Sécurité

- Changez le mot de passe admin par défaut (`nextcloud_office_collabora_admin_password`)
- Configurez SSL/TLS pour la production (`nextcloud_office_collabora_ssl`)
- Limitez l'accès au port 9980 via le firewall

## Dépannage

### Vérifier le conteneur Collabora

```bash
docker ps | grep collabora
docker logs collabora-online
```

### Vérifier les applications Nextcloud

```bash
sudo nextcloud.occ app:list
```

### Redémarrer les services

```bash
# Redémarrer Collabora
docker restart collabora-online

# Redémarrer Nextcloud
sudo snap restart nextcloud
```

## Notes

- Ce rôle doit être exécuté après l'installation de Nextcloud
- Le conteneur Collabora utilise le mode réseau host pour simplifier la configuration
- Pour la production, utilisez un reverse proxy (nginx) pour SSL/TLS
