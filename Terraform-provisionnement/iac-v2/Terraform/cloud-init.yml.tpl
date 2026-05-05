#cloud-config
# =============================================================================
# Template Cloud-init personnalisé
# S'exécute au premier démarrage de la VM
# =============================================================================

# Configuration utilisateur
users:
  - name: ${ssh_user}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ssh_public_key}
    ${password_config}

# Pas de mise à jour automatique (gain de temps)
package_update: false
package_upgrade: false

# Packages de base uniquement
packages:
  - qemu-guest-agent
  - curl
  - wget

# Démarrer QEMU Agent
runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - echo "Cloud-init terminé" > /var/log/cloud-init-done.log

# Configuration réseau finale
final_message: "VM prête - IP: $(hostname -I | awk '{print $1}')"
