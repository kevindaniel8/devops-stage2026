# ============================================
# Configuration Proxmox - Générée automatiquement
# Date: 2026-04-29 17:50:49
# ============================================

# --- Connexion Proxmox ---
pm_host         = "192.168.0.1"
pm_token_id     = "terraform@pve!tokenTerraform"
pm_token_secret = "aabfd267-63cc-47f7-8532-81bdea13a815"

# --- Paramètres VMs ---
proxmox_node = "pve"
template_id  = 9001
disk_storage = "local-lvm"
net_bridge   = "vmbr1"

# --- Authentification VMs ---
ssh_user       = "terraform"
vm_password    = "changeme" # utilisé uniquement en mode DEV - CHANGER CETTE VALEUR!
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICWdnokpvipk1X+xD8BKKnnjzfj/Rz35+HiiIeVJ4CLA terraform-proxmox-key"
mode           = "dev" # dev = mot de passe + clé SSH / prod = clé SSH uniquement

# --- Plage VMID ---
vmid_start = 200

# --- Définition des VMs (exemple) ---
# Ajoutez vos VMs ici ou modifiez selon vos besoins
vm_definitions = {
  # Exemple: VM de test (IP de départ: 192.168.20.200)
  test-vm = {
    ip     = "192.168.20.200"
    cores  = 2
    memory = 2048
    disk   = 20
  }

  # Exemple: VM applicative
  app-server = {
    ip     = "192.168.20.201"
    cores  = 2
    memory = 4096
    disk   = 40
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
