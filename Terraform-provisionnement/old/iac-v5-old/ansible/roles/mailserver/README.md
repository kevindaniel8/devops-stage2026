# Rôle Mailserver (docker-mailserver)

Ce rôle Ansible déploie un serveur de mail complet basé sur `docker-mailserver` (Postfix + Dovecot + Amavis + ClamAV + SpamAssassin + Fail2ban).

## Architecture

- **Image** : `docker.io/mailserver/docker-mailserver:latest`
- **Services** :
  - Postfix (SMTP)
  - Dovecot (IMAP/IMAPS/LMTP)
  - Amavis (anti-virus/anti-spam)
  - ClamAV (anti-virus)
  - SpamAssassin (anti-spam)
  - Fail2ban (protection contre les attaques)
  - OpenDKIM (signature DKIM)
  - OpenDMARC (validation DMARC)
  - Postgrey (greylisting)

## Déploiement

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy_mailserver.yml
```

## Configuration

### Variables principales (defaults/main.yml)

```yaml
mailserver_hostname: "mail.greencontracts.lan"
mailserver_image: "docker.io/mailserver/docker-mailserver:latest"

mailserver_data_dir: "/opt/mailserver/data"
mailserver_config_dir: "/opt/mailserver/config"
mailserver_state_dir: "/opt/mailserver/mail-state"

mailserver_ports:
  - "25:25"      # SMTP
  - "143:143"    # IMAP
  - "587:587"    # Submission
  - "993:993"    # IMAPS
```

### Variables d'environnement

```yaml
mailserver_env:
  - "SSL_TYPE=manual"
  - "SSL_CERT_PATH=/tmp/docker-mailserver/ssl/cert.pem"
  - "SSL_KEY_PATH=/tmp/docker-mailserver/ssl/key.pem"
  - "PERMIT_DOCKER=connected-networks"
  - "ENABLE_SPAMASSASSIN=1"
  - "ENABLE_CLAMAV=1"
  - "ENABLE_FAIL2BAN=1"
  - "ENABLE_POSTGREY=1"
  - "ONE_DIR=1"
  - "ENABLE_POP3=0"
  - "ENABLE_MANAGESIEVE=1"
  - "POSTFIX_MESSAGE_SIZE_LIMIT=50000000"
  - "ENABLE_QUOTAS=1"
```

## Commandes utiles

### Gestion des comptes mail

**Ajouter un compte mail :**
```bash
docker exec mailserver setup email add user@greencontracts.lan password
```

**Supprimer un compte mail :**
```bash
docker exec mailserver setup email del user@greencontracts.lan
```

**Lister les comptes mail :**
```bash
docker exec mailserver setup email list
```

**Modifier le mot de passe :**
```bash
docker exec mailserver setup email update user@greencontracts.lan newpassword
```

### Gestion des alias

**Ajouter un alias :**
```bash
docker exec mailserver setup alias add alias@greencontracts.lan user@greencontracts.lan
```

**Supprimer un alias :**
```bash
docker exec mailserver setup alias del alias@greencontracts.lan
```

**Lister les alias :**
```bash
docker exec mailserver setup alias list
```

### Configuration du relais SMTP

**Configurer un relais SMTP :**
```bash
docker exec mailserver setup relay host-smtp.example.com \
  --user smtpuser \
  --pass smtppass
```

### Gestion des quotas

**Modifier le quota d'un utilisateur :**
```bash
docker exec mailserver setup quota set user@greencontracts.lan 1G
```

**Afficher le quota d'un utilisateur :**
```bash
docker exec mailserver setup quota get user@greencontracts.lan
```

### Debug et logs

**Voir les logs :**
```bash
docker logs mailserver
```

**Voir les logs en temps réel :**
```bash
docker logs -f mailserver
```

**Voir la queue Postfix :**
```bash
docker exec mailserver postfix queue
```

**Vider la queue Postfix :**
```bash
docker exec mailserver postfix flush
```

### Test d'envoi d'email

**Envoyer un email de test :**
```bash
docker exec mailserver sh -c 'echo "Subject: Test\n\nTest email" | sendmail -f admin@greencontracts.lan user@greencontracts.lan'
```

## Intégration de nouveaux comptes

### Méthode 1 : Via commandes Docker

```bash
# Ajouter un utilisateur
docker exec mailserver setup email add jean.dupont@greencontracts.lan motdepasse

# Ajouter un alias
docker exec mailserver setup alias add jean@greencontracts.lan jean.dupont@greencontracts.lan
```

### Méthode 2 : Via fichier postfix-accounts.cf

Le fichier `/opt/mailserver/config/postfix-accounts.cf` contient les comptes mail :

```
user1@greencontracts.lan|{SHA512-CRYPT}hash|user1|
user2@greencontracts.lan|{SHA512-CRYPT}hash|user2|
```

**Générer un hash SHA512-CRYPT :**
```bash
docker exec mailserver setup email hash motdepasse
```

## Intégration avec Moodle

### Configuration SMTP dans Moodle

Dans `config.php` ou via l'interface d'administration Moodle :

```php
$CFG->smtphosts = '192.168.20.3';
$CFG->smtpsecure = 'tls';
$CFG->smtpport = 587;
$CFG->smtpuser = 'noreply@greencontracts.lan';
$CFG->smtppass = 'motdepasse';
$CFG->smtpauthtype = 'PLAIN';
$CFG->smtpmaxbulk = 10;
```

### Création du compte noreply

```bash
docker exec mailserver setup email add noreply@greencontracts.lan motdepasse
```

## Intégration avec Nextcloud

### Configuration SMTP dans Nextcloud

Via l'interface d'administration (Paramètres > Courriel électronique) :

- **Mode d'envoi** : SMTP
- **Adresse du serveur** : 192.168.20.3
- **Port** : 587
- **SSL/TLS** : TLS
- **Authentification** : Requise
- **Identifiant** : nextcloud@greencontracts.lan
- **Mot de passe** : motdepasse

### Création du compte nextcloud

```bash
docker exec mailserver setup email add nextcloud@greencontracts.lan motdepasse
```

## Intégration avec LDAP (Samba-AD)

### Prérequis

- Serveur Samba-AD opérationnel
- docker-mailserver doit pouvoir accéder au serveur LDAP
- Compte de service LDAP avec droits de lecture

### Configuration LDAP

docker-mailserver ne supporte pas nativement l'authentification LDAP. Pour intégrer avec Samba-AD, deux solutions :

#### Solution 1 : Utiliser un outil de synchronisation

**ldap2dovecot** : Synchroniser les utilisateurs LDAP vers Dovecot

```bash
# Installation sur l'hôte
apt install ldap2dovecot

# Configuration
cat > /etc/ldap2dovecot.conf << EOF
ldap_uri = ldap://192.168.20.10
ldap_base_dn = dc=greencontracts,dc=lan
ldap_bind_dn = cn=admin,dc=greencontracts,dc=lan
ldap_bind_pw = motdepasse
ldap_filter = (objectClass=user)
EOF

# Synchronisation
ldap2dovecot
```

#### Solution 2 : Utiliser dovecot-ldap-director

Modifier la configuration Dovecot dans docker-mailserver pour utiliser l'authentification LDAP.

**Fichier de configuration LDAP :**
```bash
docker exec mailserver sh -c 'cat > /etc/dovecot/dovecot-ldap.conf.ext << EOF
hosts = 192.168.20.10
base = dc=greencontracts,dc=lan
dn = cn=admin,dc=greencontracts,dc=lan
dnpass = motdepasse
auth_bind = yes
ldap_version = 3
user_filter = (&(objectClass=user)(sAMAccountName=%u))
user_attrs = =home=/var/mail/%d/%n,=mail=maildir:/var/mail/%d/%n
pass_filter = (&(objectClass=user)(sAMAccountName=%u))
EOF'
```

**Activer l'authentification LDAP dans Dovecot :**
```bash
docker exec mailserver sh -c 'echo "passdb { driver = ldap args = /etc/dovecot/dovecot-ldap.conf.ext }" >> /etc/dovecot/conf.d/10-auth.conf'
docker exec mailserver sh -c 'echo "userdb { driver = ldap args = /etc/dovecot/dovecot-ldap.conf.ext }" >> /etc/dovecot/conf.d/10-auth.conf'
docker restart mailserver
```

### Limitations

- docker-mailserver ne gère pas nativement la synchronisation bidirectionnelle
- Les modifications dans Samba-AD ne sont pas automatiquement répercutées
- Il faut utiliser des scripts de synchronisation ou des outils tiers

## Sécurité

### Certificats SSL

Le rôle génère automatiquement des certificats SSL self-signed pour le chiffrement TLS. Pour une production, utiliser des certificats Let's Encrypt ou une CA interne.

### Filtrage anti-spam

- **SpamAssassin** : Filtrage basé sur les règles SpamAssassin
- **Postgrey** : Greylisting pour réduire le spam
- **Fail2ban** : Blocage des IP après plusieurs tentatives échouées

### Limitations d'envoi vers l'extérieur

Les emails vers l'extérieur peuvent être bloqués par :
- Listes noires (Spamhaus, etc.)
- Configuration SPF/DKIM/DMARC incomplète
- IP résidentielle/FAI

**Solutions :**
- Utiliser un relais SMTP (Gmail, SendGrid, Mailgun)
- Configurer SPF/DKIM/DMARC pour le domaine
- Utiliser une IP dédiée avec bonne réputation

## Maintenance

### Sauvegarde

```bash
# Sauvegarder les données mail
tar -czf mailserver-backup-$(date +%Y%m%d).tar.gz /opt/mailserver/data /opt/mailserver/config /opt/mailserver/mail-state

# Restaurer
tar -xzf mailserver-backup-20240605.tar.gz -C /
```

### Mise à jour

```bash
# Mettre à jour l'image
docker pull mailserver/docker-mailserver:latest

# Redémarrer le conteneur
cd /opt/mailserver/config
docker-compose down
docker-compose up -d
```

### Monitoring

**Vérifier l'état du conteneur :**
```bash
docker ps | grep mailserver
```

**Vérifier les ports :**
```bash
ss -tlnp | grep -E ':(25|587|143|993)'
```

**Vérifier les logs d'erreur :**
```bash
docker logs mailserver 2>&1 | grep -i error
```

## Dépannage

### Conteneur ne démarre pas

```bash
# Voir les logs
docker logs mailserver

# Vérifier les permissions
ls -la /opt/mailserver/config

# Recréer le conteneur
cd /opt/mailserver/config
docker-compose down
docker-compose up -d
```

### Emails non reçus

```bash
# Vérifier la queue Postfix
docker exec mailserver mailq

# Vérifier les logs Postfix
docker logs mailserver 2>&1 | grep postfix

# Tester la connexion SMTP
telnet 192.168.20.3 25
```

### Erreur SSL

```bash
# Vérifier les certificats
ls -la /opt/mailserver/config/ssl/

# Régénérer les certificats
rm -rf /opt/mailserver/config/ssl/*
cd /opt/mailserver/config
docker-compose down
docker-compose up -d
```

## Ressources

- [Documentation officielle docker-mailserver](https://docker-mailserver.github.io/docker-mailserver/)
- [Postfix documentation](http://www.postfix.org/documentation.html)
- [Dovecot documentation](https://wiki.dovecot.org/)
- [SpamAssassin documentation](https://spamassassin.apache.org/)
