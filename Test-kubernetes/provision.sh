#!/bin/bash

# Script de provisionnement minimal pour les VMs K3s
# K3s gère la plupart de la configuration lui-même

echo "=== Provisionnement minimal K3s ==="

# Mise à jour du système
echo "Mise à jour du système..."
apt-get update

echo "=== Provisionnement terminé ==="
echo "Les machines sont prêtes pour K3s"
