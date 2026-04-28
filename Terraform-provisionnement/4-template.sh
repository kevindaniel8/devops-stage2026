#!/bin/bash
set -euo pipefail

STORAGE="local-lvm"
BRIDGE="vmbr0"

############################################
# 1. UBUNTU CLOUD-INIT TEMPLATE
############################################
create_ubuntu_template() {
    ID=9000
    ISO="/var/lib/vz/template/iso/ubuntu-22.04-live-server.iso"

    echo "📀 Création template Ubuntu ($ID)..."

    qm create $ID --name ubuntu-golden --memory 4096 --cores 2 --net0 virtio,bridge=$BRIDGE
    qm importdisk $ID $ISO $STORAGE
    qm set $ID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$ID-disk-0
    qm set $ID --ide2 $STORAGE:cloudinit
    qm set $ID --boot c --bootdisk scsi0
    qm set $ID --serial0 socket --vga serial0
    qm set $ID --agent enabled=1

    qm template $ID
    echo "✔️ Template Ubuntu créé : $ID"
}

############################################
# 2. DEBIAN CLOUD-INIT TEMPLATE
############################################
create_debian_template() {
    ID=9001
    ISO="/var/lib/vz/template/iso/debian-12.5.0-amd64-netinst.iso"

    echo "📀 Création template Debian ($ID)..."

    qm create $ID --name debian-golden --memory 4096 --cores 2 --net0 virtio,bridge=$BRIDGE
    qm importdisk $ID $ISO $STORAGE
    qm set $ID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$ID-disk-0
    qm set $ID --ide2 $STORAGE:cloudinit
    qm set $ID --boot c --bootdisk scsi0
    qm set $ID --serial0 socket --vga serial0
    qm set $ID --agent enabled=1

    qm template $ID
    echo "✔️ Template Debian créé : $ID"
}

############################################
# 3. TRUENAS SCALE TEMPLATE (pas cloud-init)
############################################
create_truenas_template() {
    ID=9002
    ISO="/var/lib/vz/template/iso/TrueNAS-SCALE-24.04.1.iso"

    echo "📀 Création VM TrueNAS ($ID)..."

    qm create $ID --name truenas-template --memory 8192 --cores 4 --net0 virtio,bridge=$BRIDGE
    qm set $ID --scsihw virtio-scsi-pci --scsi0 $STORAGE:64
    qm set $ID --ide2 $ISO,media=cdrom
    qm set $ID --boot order=ide2
    qm set $ID --serial0 socket --vga serial0

    echo "⚠️ Installe TrueNAS manuellement puis exécute : qm template $ID"
}

############################################
# MAIN
############################################
create_ubuntu_template
create_debian_template
create_truenas_template

echo "🎉 Tous les templates ont été créés."
