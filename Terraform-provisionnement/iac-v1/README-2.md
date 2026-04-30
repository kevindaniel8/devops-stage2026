# 2-create-user-proxmox.sh - Création utilisateur Terraform sur Proxmox

Script exécuté sur le serveur Proxmox pour créer l'utilisateur Terraform, son rôle, son token API et générer le fichier de configuration.

## 🚀 Fonctionnalités

- **Idempotent** : Nettoie automatiquement les ressources existantes avant recréation
- **6 fonctions modulaires** : Code structuré et maintenable
- **Logging sur stderr** : Logs colorés sans pollution de stdout
- **Gestion clé SSH** : Installe la clé dans `/root/.ssh/` et `/home/kevin-stage-devops/ssh/`
- **Token API** : Génère un token avec extraction automatique du secret
- **Fichier Terraform** : Génère `/home/kevin-stage-devops/terraform-config.txt`

## 📋 Prérequis

- Serveur Proxmox installé et configuré
- Accès root au serveur Proxmox (via SSH ou console)
- Script copié sur le serveur Proxmox
- `pveum` (Proxmox User Manager) disponible

## 🛠️ Utilisation

### Exécution directe sur Proxmox

```bash
# Sur le serveur Proxmox
chmod +x 2-create-user-proxmox.sh
./2-create-user-proxmox.sh "<clé_ssh_publique>" "<chemin_fichier_config>"
```

### Exécution via pipeline (recommandé)

Utilisez le script `0-main.sh` qui orchestre tout automatiquement :

```bash
# Depuis votre machine locale
./0-main.sh
```

## 🔧 Paramètres

| Paramètre | Défaut | Description |
|-----------|--------|-------------|
| `$1` | `""` | Contenu de la clé SSH publique |
| `$2` | `/home/kevin-stage-devops/terraform-config.txt` | Chemin du fichier de configuration généré |

## 📁 Structure du code (6 fonctions)

| Fonction | Description |
|----------|-------------|
| `delete_existing()` | Supprime user, role, token, ACL existants (1.1-1.2) |
| `create_user_and_role()` | Crée l'utilisateur et le rôle Terraform (2.1-2.3) |
| `create_token()` | Génère le token API et retourne le secret (3.1-3.3) |
| `install_ssh_key()` | Installe la clé SSH (4.1-4.4) |
| `generate_terraform_config()` | Génère le fichier `terraform-config.txt` (5.1-5.2) |
| `main()` | Orchestration complète (6.1-6.2) |

## 🎯 Ressources créées

### Sur Proxmox

| Ressource | Nom | Description |
|-----------|-----|-------------|
| **Utilisateur** | `terraform@pve` | Utilisateur dédié Terraform |
| **Rôle** | `TerraformRole` | Permissions VM, Datastore, Network |
| **Token** | `terraform-token` | Token API avec privsep=0 |
| **ACL** | `/` | Attribution du rôle à l'utilisateur |

### Fichiers générés

```
/root/.ssh/
└── id_ed25519_terraform-proxmox.pub    # Clé SSH pour root

/home/kevin-stage-devops/
├── ssh/
│   └── id_ed25519_terraform-proxmox.pub  # Copie de sécurité
└── terraform-config.txt                  # Configuration Terraform
```

## 📄 Contenu du fichier généré

Exemple de `terraform-config.txt` :

```hcl
pm_host         = "192.168.0.1"
pm_token_id     = "terraform@pve!terraform-token"
pm_token_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
proxmox_node    = "pve"
template_id     = 800
disk_storage    = "local-lvm"
net_bridge      = "vmbr1"

ssh_user        = "ubuntu"
vm_password     = "ubuntu"
ssh_public_key  = "ssh-ed25519 AAAAC3NzaC1..."
mode            = "dev"

vmid_start      = 500
gateway         = "192.168.20.1"
dns_server      = "8.8.8.8"
```

## 🔐 Permissions du rôle TerraformRole

```
VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU
VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory
VM.Config.Network VM.Config.Options VM.Console VM.PowerMgmt
Datastore.Allocate Datastore.AllocateSpace Datastore.Audit
```

## 📁 Structure du projet Terraform

```
.
├── 0-main.sh                     # Orchestrateur principal
├── 1-generate-ssh-keys.sh        # Génération clés SSH
├── 2-create-user-proxmox.sh      # Configuration Proxmox
├── main.tf                       # Configuration Terraform
├── variables.tf                  # Variables Terraform
├── terraform.tfvars              # Variables d'environnement
├── cloudinit.yaml                # Configuration Cloud-Init
├── ssh/                          # Clés SSH générées
│   ├── id_ed25519_terraform-proxmox
│   ├── id_ed25519_terraform-proxmox.pub
│   ├── terraform-ssh-config.txt
│   └── github-actions-example.yml
├── README-0.md                   # Doc orchestrateur
├── README-1.md                   # Doc génération SSH
└── README-2.md                   # Doc Proxmox (ce fichier)
```

## 🔧 Variables configurables

Dans le script `2-create-user-proxmox.sh` :

| Variable | Valeur | Description |
|----------|--------|-------------|
| `USER_ID` | `terraform` | Nom de l'utilisateur |
| `REALM` | `pve` | Realm Proxmox |
| `ROLE_ID` | `TerraformRole` | Nom du rôle |
| `TOKEN_ID` | `terraform-token` | ID du token |
| `PERMISSION_PATH` | `/` | Chemin des permissions |
| `OUTPUT_FILE` | `/home/kevin-stage-devops/terraform-config.txt` | Fichier de sortie |

## 🛠️ Commandes utiles

### Gestion Proxmox

```bash
# Lister les utilisateurs
ssh root@192.168.0.1 "pveum user list"

# Lister les tokens
ssh root@192.168.0.1 "pveum user token list terraform@pve"

# Vérifier les permissions
ssh root@192.168.0.1 "pveum acl list | grep terraform@pve"

# Lister les VM
ssh root@192.168.0.1 "qm list"
```

### Gestion Terraform

```bash
# Initialiser le projet
terraform init

# Valider la configuration
terraform validate

# Formater le code
terraform fmt

# Planifier les changements
terraform plan

# Appliquer les changements
terraform apply

# Détruire les ressources
terraform destroy

# Afficher l'état
terraform show

# Importer des ressources existantes
terraform import proxmox_virtual_environment_vm.nom_vm <vmid>
```

## 🔐 Sécurité

- Le fichier `terraform-config.txt` est créé avec des permissions `600` (lecture seule pour root)
- Le token API est régénéré à chaque exécution du script
- L'utilisateur Terraform a uniquement les permissions nécessaires

## 🔄 Idempotence

Le script `2-create-user-proxmox.sh` est complètement idempotent :

1. **Étape 1** : Supprime user, role, token, ACL existants
2. **Étape 2** : Recrée toutes les ressources propres
3. **Étape 3** : Génère un nouveau token et un fichier à jour

**Réinitialisation complète :**

```bash
# Depuis votre machine locale
./0-main.sh

# Ou directement sur Proxmox
./2-create-user-proxmox.sh "<clé_ssh>" "/home/kevin-stage-devops/terraform-config.txt"
```

## 🚨 Dépannage

### Erreurs courantes

| Erreur | Cause | Solution |
|----------|-------|----------|
| `Permission denied` | Droits root manquants | Vérifiez que vous êtes root sur Proxmox |
| `pveum: command not found` | Environnement non Proxmox | Ce script doit être exécuté sur un serveur Proxmox |
| `Token secret : <SECRET_NON_RECUPERE>` | Format de sortie différent | Vérifiez la version de Proxmox |
| `mkdir: cannot create directory` | Permissions système | Vérifiez les droits sur `/home/kevin-stage-devops/` |
| `Connection refused` | SSH non accessible | Vérifiez le firewall et le service SSH |

### Logs et debug

```bash
# Activer le mode debug
bash -x 2-create-user-proxmox.sh "<clé>"

# Vérifier les ressources créées
pveum user list
pveum role list
pveum acl list
pveum user token list terraform@pve

# Vérifier le fichier généré
cat /home/kevin-stage-devops/terraform-config.txt
```

## 📚 Voir aussi

- [README-0.md](README-0.md) - Documentation de l'orchestrateur
- [README-1.md](README-1.md) - Documentation de la génération SSH

---

**Note** : Ce projet est conçu pour être utilisé dans un environnement de développement et de test. Adaptez les configurations selon vos besoins de production.
