# Observability Role

Ce rôle Ansible configure automatiquement les alertes et métriques Beszel pour tous les services de l'infrastructure, avec une priorité accordée aux services critiques.

## Services Critiques Identifiés

### Priority 1 (Critique)
- **PostgreSQL Master** : Base de données principale
- **PostgreSQL Replica** : Réplication de base de données
- **Reverse Proxy** : Point d'entrée unique
- **Samba AD DC** : Authentification et DNS
- **K3s Cluster** : Orchestration conteneurs
- **Harbor** : Registry Docker

### Priority 2 (Important)
- **Nextcloud** : Stockage et collaboration
- **Mailserver** : Email
- **Moodle** : LMS
- **ArgoCD** : GitOps

### Priority 3 (Secondaire)
- **WikiJS** : Documentation
- **OpenProject** : Gestion de projet
- **Beszel Hub** : Monitoring

## Métriques Configurées

### Métriques Standard
- **CPU** : Utilisation processeur (warning/critical)
- **Memory** : Utilisation mémoire (warning/critical)
- **Disk** : Utilisation disque (warning/critical)

### Métriques Spécifiques par Service
- **PostgreSQL** : Connections, replication lag
- **Reverse Proxy** : Response time
- **Samba AD DC** : DNS response time
- **K3s Cluster** : Pod restart count
- **Mailserver** : Queue size

## Seuils d'Alerte par Priorité

### Priority 1 (Critique)
- CPU: 80% warning / 90% critical
- Memory: 75-80% warning / 85-90% critical
- Disk: 80% warning / 90% critical

### Priority 2 (Important)
- CPU: 70% warning / 85% critical
- Memory: 75% warning / 85% critical
- Disk: 85% warning / 95% critical

### Priority 3 (Secondaire)
- CPU: 80% warning / 90% critical
- Memory: 80% warning / 90% critical
- Disk: 85% warning / 95% critical

## Variables Principales

- `observability_enabled` : Active/désactive le rôle
- `observability_beszel_hub_host` : Hôte du hub Beszel
- `observability_alert_enabled` : Active les alertes
- `observability_alert_notification_enabled` : Active les notifications
- `observability_alert_email` : Email pour les notifications
- `observability_services` : Configuration des services et métriques

## Utilisation

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_observability.yml
```

### Avec variables personnalisées

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_observability.yml \
  -e "observability_alert_email=admin@example.com" \
  -e "observability_alert_enabled=true"
```

## Fonctionnement

1. Se connecte au hub Beszel via Docker
2. Récupère la liste des systèmes enregistrés
3. Configure les alertes pour chaque service selon sa priorité
4. Insère les seuils d'alerte dans la base de données Beszel
5. Configure les notifications email

## Architecture

Le rôle utilise la base de données SQLite du hub Beszel (`/beszel_data/data.db`) pour insérer directement les configurations d'alertes dans la table `alerts`.

## Personnalisation

Pour ajouter un nouveau service, ajoutez une entrée dans `observability_services` dans `defaults/main.yml` :

```yaml
nouveau_service:
  priority: 2
  name: "Mon Service"
  host: "mon-host"
  metrics:
    cpu:
      warning: 70
      critical: 85
    memory:
      warning: 75
      critical: 85
  alerts_enabled: true
```

## Dépannage

### Vérifier les alertes configurées

```bash
ssh ubuntu@192.168.20.4 "docker exec beszel-server sqlite3 /beszel_data/data.db 'SELECT * FROM alerts;'"
```

### Vérifier les systèmes enregistrés

```bash
ssh ubuntu@192.168.20.4 "docker exec beszel-server sqlite3 /beszel_data/data.db 'SELECT * FROM systems;'"
```

### Redéployer la configuration

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_observability.yml
```

## Notes

- Ce rôle nécessite que le hub Beszel soit installé et fonctionnel
- Les alertes sont configurées directement dans la base de données Beszel
- Les services doivent être enregistrés dans Beszel avant la configuration des alertes
- Le rôle peut être exécuté plusieurs fois sans problème (idempotent)
