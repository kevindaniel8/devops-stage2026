# Samba AD DC - Infrastructure as Code

Ce projet déploie un contrôleur de domaine Samba Active Directory avec Vagrant et Ansible.

## Architecture

- **VM** : Ubuntu 24.04
- **Domaine** : LAB.LOCAL
- **IP** : 192.168.56.5
- **Rôle Ansible** : Configuration complète du contrôleur de domaine

## Prérequis

- VirtualBox
- Vagrant
- Ansible (sur la machine hôte)

## Commandes

### 1. Démarrage de l'infrastructure

```bash
# Démarrer la VM (création si n'existe pas)
vagrant up

# Si la VM existe déjà et doit être redémarrée
vagrant reload
```

### 2. Provisionnement du contrôleur de domaine

⚠️ **Important** : Le provisionnement automatique via Vagrant est désactivé car il y a des problèmes de chemins de rôles Ansible.

```bash
# Se placer dans le dossier ansible
cd ansible

# Lancer le provisionnement
ansible-playbook -i inventories/dev/hosts.yml playbooks/playbook.yml
```

### 3. Vérification du fonctionnement

```bash
# Vérifier que le service Samba AD DC est actif
vagrant ssh
sudo systemctl status samba-ad-dc

# Lister les utilisateurs du domaine
sudo samba-tool user list

# Tester la résolution DNS interne
host -t SRV _ldap._tcp.lab.local

# Tester la résolution DNS externe
nslookup google.com
```

### 4. Gestion de l'infrastructure

```bash
# Arrêter la VM
vagrant halt

# Détruire la VM (suppression complète)
vagrant destroy

# Se connecter à la VM
vagrant ssh

# Vérifier l'état de la VM
vagrant status
```

## Structure du projet

```
v1/
├── Vagrantfile              # Configuration Vagrant de la VM
├── ansible/
│   ├── ansible.cfg          # Configuration Ansible
│   ├── inventories/        # Inventaires des hôtes
│   │   ├── dev/
│   │   │   └── hosts.yml
│   │   └── prod/
│   │       └── inventory.yml
│   ├── playbooks/
│   │   └── playbook.yml   # Playbook principal
│   └── roles/
│       └── samba-ad-dc/   # Rôle de configuration
│           ├── defaults/
│           │   └── main.yml
│           ├── handlers/
│           │   └── main.yml
│           ├── tasks/
│           │   ├── main.yml
│           │   ├── install.yml
│           │   ├── configure.yml
│           │   └── provision.yml
│           └── templates/
│               └── resolv.conf.j2
└── README.md               # Ce fichier
```

## Configuration

### Variables principales (defaults/main.yml)

- `samba_domain`: LAB
- `samba_realm`: LAB.LOCAL  
- `samba_admin_password`: ChangeMe123!
- `samba_dns_forwarder`: 8.8.8.8

### Réseau

- **IP privée** : 192.168.56.5
- **Nom d'hôte** : samba-ad-dc
- **Port SSH** : 2222 (forward depuis l'hôte)

## Fonctionnalités déployées

✅ **Services Samba**
- Contrôleur de domaine Active Directory
- Services LDAP
- Services Kerberos
- Services DNS interne

✅ **Configuration système**
- Désactivation des services Samba legacy (smbd, nmbd, winbind)
- Configuration DNS avec forwarder vers 8.8.8.8
- Backup des configurations existantes

✅ **Sécurité**
- Utilisateur vagrant avec clé SSH dédiée
- Élévation de privilèges via sudo
- Isolation réseau

## Dépannage

### Problèmes connus

1. **Provisionnement automatique Vagrant**
   - **Problème** : Vagrant ne trouve pas les rôles Ansible
   - **Solution** : Utiliser le provisionnement manuel

2. **DNS forwarder**
   - **Problème** : Message "Global parameter dns forwarder found in service section!"
   - **Solution** : Utiliser `--option='dns forwarder = {{ samba_dns_forwarder }}'` dans samba-tool

### Commandes de dépannage

```bash
# Vérifier la connectivité SSH
ssh -i .vagrant/machines/default/virtualbox/private_key vagrant@192.168.56.5

# Vérifier les logs Samba
vagrant ssh
sudo journalctl -u samba-ad-dc -f

# Tester l'authentification Kerberos
vagrant ssh
kinit administrator@LAB.LOCAL

# Vérifier la configuration DNS
vagrant ssh
sudo samba-tool dns query 127.0.0.1 lab.local A
```

## Notes importantes

- Le mot de passe administrateur par défaut est `ChangeMe123!` 
- Pensez à le modifier en environnement de production
- La VM utilise 2GB RAM et 2 CPU (configurable dans Vagrantfile)
- Le domaine est fonctionnel après le provisionnement Ansible

## Maintenance

Pour mettre à jour la configuration :

1. Modifier les fichiers dans le dossier `ansible/roles/samba-ad-dc/`
2. Relancer le provisionnement : `ansible-playbook -i inventories/dev/hosts.yml playbooks/playbook.yml`
3. Redémarrer les services si nécessaire : `vagrant ssh && sudo systemctl restart samba-ad-dc`
