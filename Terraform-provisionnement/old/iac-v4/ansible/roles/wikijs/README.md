# Wiki.js Role

Déploiement Wiki.js avec PostgreSQL distant.

---

## 🏗 Architecture

- Wiki.js → 192.168.20.4
- PostgreSQL → 192.168.20.20
- DB créée par Ansible via SSH

---

## ⚙ Fonctionnement

1. Ansible se connecte à la VM PostgreSQL
2. Crée user + base + droits
3. Déploie Wiki.js sur VM dédiée
4. Wiki.js initialise ses tables automatiquement

---

## 📦 Dépendances

- Docker installé via ton rôle docker
- SSH accès à VM PostgreSQL (ubuntu + clé)

---

## ▶ Exemple playbook

```yaml
- hosts: wikijs
  become: true
  roles:
    - docker
    - wikijs