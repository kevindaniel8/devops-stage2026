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
  vm_list = keys(var.vm_definitions)
  ssh_pwauth = var.mode == "dev" ? true : false
}

resource "proxmox_virtual_environment_vm" "vms" {
  for_each = var.vm_definitions

  vm_id     = var.vmid_start + index(local.vm_list, each.key)
  name      = each.key
  node_name = var.proxmox_node

  agent {
    enabled = var.wait_for_cloudinit
  }

  # Démarrage différé si on ne veut pas attendre cloud-init
  on_boot = var.wait_for_cloudinit

  clone {
    vm_id = var.template_id
    full  = false
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
    file_format  = "qcow2"
  }

  network_device {
    bridge = var.net_bridge
    model  = "virtio"
  }

  initialization {
    user_account {
      username = var.ssh_user
      password = local.ssh_pwauth ? var.vm_password : null
      keys     = [trimspace(var.ssh_public_key)]
    }

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
