#cloud-config
# =============================================================================
# Template Cloud-init ULTRA-OPTIMISÉ
# Objectif: Minimiser le temps de provisioning
# =============================================================================

# --- Configuration utilisateur ---
users:
  - name: ${ssh_user}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ssh_public_key}%{ if password_hash != "" }
    passwd: ${password_hash}%{ endif }

# --- Désactiver TOUTES les mises à jour (gain ~5-10 min) ---
package_update: false
package_upgrade: false

# --- Désactiver le growpart (déjà fait dans le template) ---
growpart:
  mode: off

# --- Minimiser les modules exécutés (gain ~30s) ---
cloud_init_modules:
  - migrator
  - seed_random
  - growpart
  - resizefs
  - set_hostname
  - update_hostname
  - users-groups
  - ssh

cloud_config_modules:
  - runcmd
  - timezone

cloud_final_modules: []

# --- Démarrage rapide sans attente réseau ---
bootcmd:
  - echo "Démarrage rapide cloud-init" > /dev/ttyS0

# --- Pas de attente pour le réseau (gain ~5-15s) ---
network:
  config: disabled

# --- Packages MINIMALES ---
packages:
  - qemu-guest-agent

package_reboot_if_required: false

# --- Actions au démarrage ---
runcmd:
  - systemctl enable qemu-guest-agent --now 2>/dev/null || true
  - echo "VM prete - IP: $(hostname -I | awk '{print $1}')" > /var/log/cloud-init-done.log

# --- Message final ---
final_message: "Cloud-init termine en $UPTIME secondes"
