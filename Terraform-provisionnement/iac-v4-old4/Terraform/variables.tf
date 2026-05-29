variable "pm_host" {
  description = "Hostname or IP of the Proxmox server"
  type        = string
}

variable "pm_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}

variable "pm_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node on which VMs will be created"
  type        = string
}

variable "template_id" {
  description = "VM template ID used for cloning"
  type        = number
}

variable "disk_storage" {
  description = "Datastore used for VM disks"
  type        = string
  default     = "local-lvm" # Exemple de stockage courant
}

variable "net_bridge" {
  description = "Network bridge used for VM network interfaces"
  type        = string
  default     = "vmbr0" # Valeur par défaut standard sur Proxmox
}

variable "ssh_user" {
  description = "Default SSH username for VM initialization"
  type        = string
  default     = "debian" # Valeur par défaut courante pour Debian
}

variable "vm_password" {
  description = "Password for the VM user (used only in DEV mode)"
  type        = string
  sensitive   = true
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "SSH public key to inject into VMs"
  type        = string
}

variable "mode" {
  description = "Deployment mode: dev (SSH password + key) or prod (SSH key only)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.mode)
    error_message = "Mode must be either 'dev' or 'prod'."
  }
}

variable "vmid_start" {
  description = "Starting VMID for automatic VMID assignment"
  type        = number
  default     = 200
}

variable "vm_definitions" {
  description = "Map of VM definitions including IP, CPU, RAM, and disk size"
  type = map(object({
    ip     = string
    cores  = number
    memory = number
    disk   = number
  }))
}

variable "gateway" {
  description = "Default gateway for VM network configuration"
  type        = string
}

variable "dns_server" {
  description = "DNS server for VM configuration"
  type        = string
}

variable "wait_for_cloudinit" {
  description = "Wait for cloud-init to complete (slower but ensures VM is ready)"
  type        = bool
  default     = false
}