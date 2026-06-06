# Gestion des Certificats SSL/TLS

## Architecture

Cette infrastructure utilise 3 rôles Ansible pour gérer les certificats SSL/TLS :

### 1. **ssl-ca-interne** - CA Interne pour Services LAN
- Génère une CA racine X.509
- Génère des certificats signés par cette CA pour les services internes
- Utilise les modules Ansible `community.crypto` pour l'idempotence
- Déploie la CA sur tous les clients
- Chemins relatifs (indépendants de la machine hôte)

### 2. **ssl-letsencrypt** - Certificats Let's Encrypt
- Installe certbot sur le reverse-proxy
- Génère des certificats Let's Encrypt pour les services exposés publiquement
- Configure le renouvellement automatique via cron
- Déploie les certificats sur le reverse-proxy

### 3. **ssl-distribute** - Distribution des Certificats
- Distribue la CA interne aux clients
- Distribue la CA Let's Encrypt aux clients
- Met à jour le store de certificats système

### 4. **ssl-orchestrator.yml** - Playbook Orchestrateur
- Orchestre les 3 rôles
- Lit le catalogue de services depuis `hosts.yml`
- Génère les certificats selon le `tls_mode` de chaque service
- Active TLS sur le reverse-proxy
- Vérifie les certificats

## Configuration

### Variables dans `env.conf`

```bash
# Mode TLS global : internal_ca | letsencrypt | mixed
TLS_MODE="mixed"

# CA Interne
CA_COMMON_NAME="GreenContracts-Root-CA"
CA_VALIDITY_DAYS="3650"
CERT_VALIDITY_DAYS="365"
CERT_KEY_SIZE="4096"

# Let's Encrypt
LETSENCRYPT_EMAIL="admin@greencontracts.lan"
LETSENCRYPT_STAGING="false"  # true pour tests
```

### Configuration des Services dans `hosts.yml`

Chaque service dans le catalogue `hosts.yml` doit avoir un `tls_mode` :

```yaml
services:
  reverse_proxy:
    fqdn: "proxy.greencontracts.lan"
    tls_mode: "internal_ca"  # none | letsencrypt | internal_ca
    expose_external: false

  moodle:
    fqdn: "moodle.greencontracts.lan"
    tls_mode: "letsencrypt"
    expose_external: true

  argocd:
    fqdn: "argocd.greencontracts.lan"
    tls_mode: "internal_ca"
    expose_external: false
```

## Utilisation

### Installation des Dépendances

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

### Exécution du Playbook

```bash
# Exécuter tout le playbook (CA + Let's Encrypt + Distribution + Activation)
ansible-playbook -i inventories/dev/hosts.yml playbooks/ssl-orchestrator.yml

# Exécuter uniquement la CA interne
ansible-playbook -i inventories/dev/hosts.yml playbooks/ssl-orchestrator.yml --tags ca-interne

# Exécuter uniquement Let's Encrypt
ansible-playbook -i inventories/dev/hosts.yml playbooks/ssl-orchestrator.yml --tags letsencrypt

# Exécuter uniquement la distribution
ansible-playbook -i inventories/dev/hosts.yml playbooks/ssl-orchestrator.yml --tags distribute

# Exécuter uniquement l'activation TLS
ansible-playbook -i inventories/dev/hosts.yml playbooks/ssl-orchestrator.yml --tags activate-tls

# Exécuter uniquement la vérification
ansible-playbook -i inventories/dev/hosts.yml playbooks/ssl-orchestrator.yml --tags verify
```

## Structure des Certificats

### CA Interne
- **Stockage local** : `ansible/files/pki/ca/`
- **Clé privée** : `ca.key`
- **Certificat** : `ca.crt`

### Certificats Services
- **Stockage local** : `ansible/files/pki/certs/`
- **Clés privées** : `ansible/files/pki/keys/`
- **Format** : `{service_name}.crt`, `{service_name}.key`, `{service_name}-fullchain.crt`

### Déploiement sur Reverse-Proxy
- **Chemin** : `/etc/nginx/ssl/`
- **Format** : `{service_name}.crt`, `{service_name}.key`, `{service_name}-fullchain.crt`, `ca.crt`

### Déploiement sur Clients
- **Chemin CA** : `/usr/local/share/ca-certificates/`
- **Nom CA interne** : `greencontracts-ca.crt`
- **Nom CA Let's Encrypt** : `letsencrypt-isrgrootx1.crt`

## Idempotence

Les rôles sont conçus pour être idempotents :
- Les modules `community.crypto` ne recréent pas les certificats existants
- Certbot utilise `--keep-until-expiring` pour éviter les renouvellements inutiles
- Les tâches de copie utilisent le paramètre `creates` ou vérifient l'existence

## Sécurité

- Les clés privées sont stockées avec les permissions `0400`
- Les certificats sont stockés avec les permissions `0644`
- La CA interne est valide pour 10 ans par défaut
- Les certificats services sont valides pour 1 an par défaut
- Let's Encrypt utilise le mode staging par défaut pour les tests

## Dépannage

### Vérifier la CA interne
```bash
openssl x509 -in ansible/files/pki/ca/ca.crt -text -noout
```

### Vérifier un certificat service
```bash
openssl verify -CAfile ansible/files/pki/ca/ca.crt ansible/files/pki/certs/{service}.crt
```

### Vérifier le certificat servi par Nginx
```bash
openssl s_client -connect {fqdn}:443 -servername {fqdn} -showcerts < /dev/null
```

### Renouveler manuellement un certificat Let's Encrypt
```bash
ssh reverse-proxy
sudo certbot renew --force-renewal --cert-name {service_name}
```

## Notes

- Le playbook utilise `vars_files` pour charger le catalogue de services depuis `hosts.yml`
- Les chemins sont relatifs au playbook (`{{ playbook_dir }}/../`)
- Le reverse-proxy doit être accessible depuis Internet pour Let's Encrypt
- Les clients doivent avoir le groupe `cert_clients` dans l'inventaire
