# Cluster PostgreSQL repmgr avec Ansible - Version 2

**Version améliorée basée sur la version fonctionnelle**

## 🆔 Versions

- **V1** : `/home/kevin/Test-postgres/ansible-repmgr-cluster` ✅ Fonctionnelle
- **V2** : `/home/kevin/Test-postgres/ansible-repmgr-cluster-v2` 🚧 En développement

## 🎯 Objectifs V2

1. **Optimisation du déploiement**
2. **Gestion d'erreur améliorée**
3. **Monitoring avancé**
4. **Automatisation complète**
5. **Documentation détaillée**

## 📋 Améliorations prévues

### 🔧 Déploiement
- [ ] Validation pré-déploiement
- [ ] Rollback automatique
- [ ] Tests de santé intégrés

### 📊 Monitoring
- [ ] Dashboard Grafana
- [ ] Alertes Prometheus
- [ ] Logs centralisés

### 🛡️ Sécurité
- [ ] SSL/TLS obligatoire
- [ ] Rotation des mots de passe
- [ ] Audit des accès

### 🚀 Performance
- [ ] Tuning automatique
- [ ] Benchmarks intégrés
- [ ] Scaling horizontal

## 🔄 Workflow de développement

```bash
# Version 1 (stable)
cd /home/kevin/Test-postgres/ansible-repmgr-cluster

# Version 2 (développement)
cd /home/kevin/Test-postgres/ansible-repmgr-cluster-v2

# Tester les améliorations
./scripts/deploy_all.sh
```

## 📝 Notes de développement

- Basé sur les scripts fonctionnels de `/home/kevin/Test-postgres/rebuild_cluster_repmgr.sh`
- Utilise les mêmes paramètres que la version V1
- Compatible avec les outils existants
