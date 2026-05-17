#!/bin/bash

set -e

TEMPLATE_ID=9000
TEMPLATE_NAME="ubuntu-2404-cloudinit"
IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMG_PATH="/tmp/noble-server-cloudimg-amd64.img"
STORAGE="local-lvm"

echo "=== Téléchargement de l'image Ubuntu 24.04 cloud-init ==="
wget -O "$IMG_PATH" "$IMG_URL"

echo "=== Création de la VM $TEMPLATE_ID ==="
qm create $TEMPLATE_ID \
  --name $TEMPLATE_NAME \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0

echo "=== Import du disque RAW dans $STORAGE ==="
qm importdisk $TEMPLATE_ID "$IMG_PATH" $STORAGE --format raw

echo "=== Attachement du disque importé ==="
qm set $TEMPLATE_ID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-${TEMPLATE_ID}-disk-0

echo "=== Ajout du disque cloud-init ==="
qm set $TEMPLATE_ID --ide2 $STORAGE:cloudinit

echo "=== Activation du chipset Q35 ==="
qm set $TEMPLATE_ID --machine q35

echo "=== Activation du BIOS UEFI (OVMF) ==="
qm set $TEMPLATE_ID --bios ovmf

echo "=== Création du disque EFI ==="
qm set $TEMPLATE_ID --efidisk0 $STORAGE:1,format=raw

echo "=== Configuration du boot ==="
qm set $TEMPLATE_ID --boot c --bootdisk scsi0

echo "=== Activation de l'agent QEMU ==="
qm set $TEMPLATE_ID --agent enabled=1

echo "=== Conversion en template ==="
qm template $TEMPLATE_ID

echo "=== Template Ubuntu 24.04 cloud-init prêt ==="
qm config $TEMPLATE_ID
