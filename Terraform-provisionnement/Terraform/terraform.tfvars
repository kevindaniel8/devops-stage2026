# ============================================
# Configuration Proxmox - Générée automatiquement
# Date: 2026-04-30 18:23:15
# ============================================

# --- Connexion Proxmox ---
pm_host         = "192.168.0.1"
pm_token_id     = "terraform@pve!tokenTerraform"
pm_token_secret = "55712488-d738-4f58-9663-e67870cd4826"

# --- Paramètres VMs ---
proxmox_node = "pve"
template_id  = 9001
disk_storage = "local-lvm"
net_bridge   = "vmbr1"

# --- Authentification VMs ---
ssh_user       = "ubuntu"
vm_password    = "ubuntu"  # utilisé uniquement en mode DEV - CHANGER CETTE VALEUR!
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINFqMGnwkcpFfagqZfyNf8zjOT83WQb/OtkRoyHwxBLB terraform-proxmox-key"
mode           = "dev"  # dev = mot de passe + clé SSH / prod = clé SSH uniquement

# --- Plage VMID ---
vmid_start = 200

# --- Définition des VMs ---
# Chargé depuis: /home/kevin/devops-stage2026/Terraform-provisionnement/vm-definitions.json
# Modifiez ce fichier pour ajouter/supprimer des VMs
vm_definitions = {
  # VM de test basique
  test-vm = {
    ip     = "192.168.20.200"
    cores  = 1
    memory = 2048
    disk   = 20
  },
  # Serveur applicatif
  app-server = {
    ip     = "192.168.20.201"
    cores  = 1
    memory = 2048
    disk   = 25
  }
}

# --- Réseau ---
gateway    = "192.168.20.1"
dns_server = "8.8.8.8"

# ============================================
# Notes:
# - Template utilisé: 9001
#   (9001=Debian13, 9002=Ubuntu24.04, 9003=Ubuntu26.04)
# - Modifiez vm_definitions pour ajouter vos VMs
# - En mode 'prod', retirez vm_password
# ============================================
