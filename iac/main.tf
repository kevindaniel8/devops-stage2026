terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      #source  = "Telmate/proxmox"
      #version = ">= 3.0.0"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.pm_api_url
  pm_user         = var.pm_user
  pm_password     = var.pm_password
  pm_tls_insecure = true
}

########################
# VM PostgreSQL MASTER #
########################

resource "proxmox_vm_qemu" "pg_master" {
  name        = "pg-master"
  target_node = var.pm_node
  clone       = var.base_template_name

  cores   = 2
  sockets = 1
  memory  = 4096

  scsihw = "virtio-scsi-pci"

  disk {
    size    = "40G"
    type    = "scsi"
    storage = var.pm_storage
  }

  network {
    model  = "virtio"
    bridge = var.pm_bridge
  }

  ssh_user        = var.vm_ssh_user
  ssh_private_key = file(var.vm_ssh_private_key)

  ciuser  = var.vm_ssh_user
  cipassword = var.vm_ci_password

  ipconfig0 = "ip=${var.pg_master_ip}/24,gw=${var.pm_gateway}"

  os_type = "cloud-init"
}

###################
# VM TrueNAS (NFS)#
###################

resource "proxmox_vm_qemu" "truenas" {
  count       = var.enable_truenas ? 1 : 0
  name        = "truenas"
  target_node = var.pm_node
  clone       = var.base_template_name

  cores   = 2
  sockets = 1
  memory  = 8192

  scsihw = "virtio-scsi-pci"

  disk {
    size    = "20G"
    type    = "scsi"
    storage = var.pm_storage
  }

  disk {
    size    = var.truenas_data_disk_size
    type    = "scsi"
    storage = var.pm_storage
  }

  network {
    model  = "virtio"
    bridge = var.pm_bridge
  }

  ssh_user        = var.vm_ssh_user
  ssh_private_key = file(var.vm_ssh_private_key)

  ciuser     = var.vm_ssh_user
  cipassword = var.vm_ci_password

  ipconfig0 = "ip=${var.truenas_ip}/24,gw=${var.pm_gateway}"

  os_type = "cloud-init"
}

#################
# K3s MASTER VM #
#################

resource "proxmox_vm_qemu" "k3s_master" {
  name        = "k3s-master"
  target_node = var.pm_node
  clone       = var.base_template_name

  cores   = 2
  sockets = 1
  memory  = 2048

  scsihw = "virtio-scsi-pci"

  disk {
    size    = "20G"
    type    = "scsi"
    storage = var.pm_storage
  }

  network {
    model  = "virtio"
    bridge = var.pm_bridge
  }

  ssh_user        = var.vm_ssh_user
  ssh_private_key = file(var.vm_ssh_private_key)

  ciuser     = var.vm_ssh_user
  cipassword = var.vm_ci_password

  ipconfig0 = "ip=${var.k3s_master_ip}/24,gw=${var.pm_gateway}"

  os_type = "cloud-init"
}

###################
# K3s WORKERS VMs #
###################

resource "proxmox_vm_qemu" "k3s_worker" {
  count       = 2
  name        = "k3s-worker-${count.index + 1}"
  target_node = var.pm_node
  clone       = var.base_template_name

  cores   = 2
  sockets = 1
  memory  = 2048

  scsihw = "virtio-scsi-pci"

  disk {
    size    = "20G"
    type    = "scsi"
    storage = var.pm_storage
  }

  network {
    model  = "virtio"
    bridge = var.pm_bridge
  }

  ssh_user        = var.vm_ssh_user
  ssh_private_key = file(var.vm_ssh_private_key)

  ciuser     = var.vm_ssh_user
  cipassword = var.vm_ci_password

  ipconfig0 = "ip=${var.k3s_workers_ips[count.index]}/24,gw=${var.pm_gateway}"

  os_type = "cloud-init"
}

###############
# Samba AD VM #
###############

resource "proxmox_vm_qemu" "samba_ad" {
  name        = "samba-ad"
  target_node = var.pm_node
  clone       = var.base_template_name

  cores   = 2
  sockets = 1
  memory  = 2048

  scsihw = "virtio-scsi-pci"

  disk {
    size    = "20G"
    type    = "scsi"
    storage = var.pm_storage
  }

  network {
    model  = "virtio"
    bridge = var.pm_bridge
  }

  ssh_user        = var.vm_ssh_user
  ssh_private_key = file(var.vm_ssh_private_key)

  ciuser     = var.vm_ssh_user
  cipassword = var.vm_ci_password

  ipconfig0 = "ip=${var.samba_ad_ip}/24,gw=${var.pm_gateway}"

  os_type = "cloud-init"
}

#############################
# REPLICA PostgreSQL (VPS)  #
#############################

# Ici on suppose que le VPS est déjà créé (OVH/Scaleway/etc.)
# et qu'on passe simplement son IP à Ansible.
# Si tu veux, on pourra plus tard ajouter un provider spécifique (ex: scaleway, hetzner).

locals {
  pg_replica_ip = var.pg_replica_ip
}

################
# INVENTAIRE   #
################

# Fichier inventory Ansible généré par Terraform (optionnel, pratique)
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/inventory.ini"
  content  = <<EOT
[postgres_master]
pg-master ansible_host=${proxmox_vm_qemu.pg_master.ipconfig0}

[postgres_replica]
pg-replica ansible_host=${local.pg_replica_ip}

[k3s_master]
k3s-master ansible_host=${proxmox_vm_qemu.k3s_master.ipconfig0}

[k3s_workers]
%{ for idx, ip in var.k3s_workers_ips ~}
k3s-worker-${idx + 1} ansible_host=${ip}
%{ endfor ~}

[samba]
samba-ad ansible_host=${var.samba_ad_ip}

[truenas]
%{ if var.enable_truenas ~}
truenas ansible_host=${var.truenas_ip}
%{ endif ~}
EOT
}

