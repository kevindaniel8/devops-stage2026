# Moodle Custom Docker Image

Image Moodle personnalisée pour déploiement sur K3s avec PostgreSQL externe.

## Build de l'image

```bash
# Build local
docker build -t moodle-custom:latest .

# Tag pour Harbor
docker tag moodle-custom:latest 192.168.20.205/library/moodle:latest

# Push vers Harbor
docker push 192.168.20.205/library/moodle:latest
```

## Test local avec Docker Compose

```bash
cd docker-images/moodle
docker-compose up -d
```

Accès : http://localhost:8080

## Intégration K3s

L'image est automatiquement utilisée par le rôle Ansible `moodle-k3s` :

```yaml
# ansible/roles/moodle-k3s/defaults/main.yml
moodle_image: "192.168.20.205/library/moodle:latest"
```

## Variables d'environnement

| Variable | Description | Défaut |
|----------|-------------|--------|
| `MOODLE_DATABASE_TYPE` | Type de DB (pgsql/mysqli) | pgsql |
| `MOODLE_DATABASE_HOST` | Hôte PostgreSQL | 192.168.20.20 |
| `MOODLE_DATABASE_PORT_NUMBER` | Port DB | 5432 |
| `MOODLE_DATABASE_NAME` | Nom de la DB | moodle |
| `MOODLE_DATABASE_USER` | User DB | moodle |
| `MOODLE_DATABASE_PASSWORD` | Password DB | - |

## Déploiement

```bash
./6-deploiement-ansible.sh deploy_moodle
```
