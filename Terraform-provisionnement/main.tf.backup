terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.60.1"
    }
  }
}

provider "proxmox" {
  endpoint  = "https://${var.pm_host}:8006/"
  api_token = "${var.pm_token_id}=${var.pm_token_secret}"
  insecure  = true
}

locals {
  # Liste des VM pour générer les VMID automatiquement
  vm_list = keys(var.vm_definitions)

  # Active ou désactive l'auth SSH par mot de passe selon le mode
  ssh_pwauth = var.mode == "dev" ? true : false
}

resource "proxmox_virtual_environment_vm" "vms" {
  for_each = var.vm_definitions

  # VMID automatique basé sur vmid_start
  vm_id     = var.vmid_start + index(local.vm_list, each.key)
  name      = each.key
  node_name = var.proxmox_node

  # QEMU Agent pour remonter l’IP automatiquement
  agent {
    enabled = true
  }

  # Clonage depuis le template Cloud-Init
  clone {
    vm_id = var.template_id
  }

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.disk_storage
    size         = each.value.disk
    interface    = "scsi0"
  }

  network_device {
    bridge = var.net_bridge
    model  = "virtio"
  }

  initialization {

    # Compte utilisateur Cloud-Init
    user_account {
      username = var.ssh_user

      # Mot de passe activé seulement en DEV
      password = local.ssh_pwauth ? var.vm_password : null

      # Clé SSH obligatoire
      keys = [
        trimspace(var.ssh_public_key)
      ]
    }

    # Configuration réseau
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.dns_server]
    }
  }
}
