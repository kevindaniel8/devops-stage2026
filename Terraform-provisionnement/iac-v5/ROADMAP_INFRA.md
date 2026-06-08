# Roadmap - Optimisation Architecture iac-v3

## 🎯 Objectif
Centraliser la configuration dans un seul fichier source de vérité.

## 📁 Architecture Actuelle (à optimiser)
```
environnement          ← Modifié manuellement par l'utilisateur
vm-definitions.json    ← Doit correspondre à environnement
hosts.yml              ← Doit correspondre aux 2 précédents
```
**Problème :** 3 fichiers à maintenir → risque d'incohérence

## ✅ Architecture Cible (proposée)

### Option A : Environnement comme source (recommandé)
```
environnement.conf     ← SOURCE DE VÉRITÉ (seul fichier à modifier) definition réseau par l'utilisateur
    ↓
generate_inventory.py   ← Script de génération
    ↓
vm-definitions.json   ← Généré automatiquement ( definition des vm fixes mes ip reseau dynamique generé par env.conf)
hosts.yml              ← Généré automatiquement
```

**Fichier environnement.conf :**
```bash
# === ENVIRONNEMENT ===
ENV=dev
DOMAIN=kevin.lan
IP_BASE=192.168.20

# === MODULES (true/false) ===
ENABLE_K3S=true
ENABLE_K3S_MANAGER_SUFFIX=30
ENABLE_K3S_WORKER1_SUFFIX=31
ENABLE_K3S_WORKER2_SUFFIX=32

ENABLE_HARBOR=true
ENABLE_HARBOR_SUFFIX=205

ENABLE_DATABASE=false    # Désactivé
ENABLE_DATABASE_MASTER_SUFFIX=20
ENABLE_DATABASE_REPLICA_SUFFIX=21

ENABLE_MARIADB=true
ENABLE_MARIADB_SUFFIX=100
```

**Avantages :**
- ✅ Un seul fichier à modifier
- ✅ Active/désactive par commentaire
- ✅ Génération automatique des IPs
- ✅ Pas d'erreur de copier-coller

---

### Option B : JSON centralisé
```json
{
  "environment": "dev",
  "domain": "kevin.lan",
  "ip_base": "192.168.20",
  "modules": {
    "k3s": { "enabled": true, "manager": 30, "workers": [31, 32] },
    "harbor": { "enabled": true, "ip": 205 },
    "database": { "enabled": false, "master": 20, "replica": 21 }
  }
}
```

---

## 📋 Tâches à faire quand les modules sont stables

### Priorité 1 : Modules core
- [ ] Finaliser rôle `docker` ✅
- [ ] Finaliser rôle `harbor` ✅
- [ ] Finaliser rôle `postgresql` + `repmgr` ✅

### Priorité 2 : Kubernetes
- [ ] Créer rôle `k3s-manager`
- [ ] Créer rôle `k3s-worker`
- [ ] Créer playbook `deploy-k3s.yml`

### Priorité 3 : Optimisation architecture
- [ ] Choisir Option A ou B
- [ ] Créer script `generate_inventory.py`
- [ ] Tester génération automatique
- [ ] Supprimer duplicatas
- [ ] Documentation utilisateur

### Priorité 4 : Production-ready
- [ ] CI/CD GitHub Actions
- [ ] Tests automatisés
- [ ] Documentation complète

---

## 🔧 Script de génération (esquisse)

```python
#!/usr/bin/env python3
# generate_inventory.py - À créer plus tard

import json
import configparser

# 1. Lire environnement.conf
# 2. Générer vm-definitions.json pour Terraform
# 3. Générer hosts.yml pour Ansible
# 4. Générer variables de groupe
```

---

## 💭 Notes

**Pourquoi pas tout de suite ?**
- En développement, besoin de flexibilité
- Chaque module est testé séparément
- Une fois stable → industrialisation

**Quand faire la migration ?**
- Quand K3s est stable
- Quand tous les modules sont testés ensemble
- Avant passage en production

---

**Date création :** Mai 2026
**Auteur :** Kevin DANIEL
**Statut :** En attente (modules en cours de dev)
