#!/usr/bin/env python3
"""
Script de génération des variables Ansible depuis env.conf
Génère uniquement la partie dynamique de group_vars/all.yml
"""

import os
import re
import sys
from pathlib import Path

def parse_env_conf(env_file):
    """Parse le fichier env.conf et retourne un dict de variables"""
    variables = {}
    
    with open(env_file, 'r') as f:
        for line in f:
            line = line.strip()
            # Ignorer les commentaires et lignes vides
            if not line or line.startswith('#'):
                continue
            
            # Extraire VAR="value" ou VAR=value
            match = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)=("?)(.+?)\2$', line)
            if match:
                var_name = match.group(1)
                var_value = match.group(3)
                
                # Résoudre les références ${VAR}
                var_value = resolve_references(var_value, variables)
                
                variables[var_name] = var_value
    
    return variables

def resolve_references(value, variables):
    """Résout les références ${VAR} dans les valeurs"""
    pattern = re.compile(r'\$\{([^}]+)\}')
    
    def replace_ref(match):
        ref_name = match.group(1)
        return variables.get(ref_name, match.group(0))
    
    # Résoudre jusqu'à ce qu'il n'y ait plus de références
    prev_value = None
    while prev_value != value:
        prev_value = value
        value = pattern.sub(replace_ref, value)
    
    return value

def generate_dynamic_vars(env_vars):
    """Génère les variables dynamiques pour Ansible"""
    
    subnet = env_vars.get('SUBNET', '192.168.20')
    domain = env_vars.get('DOMAIN', 'greencontracts.org')
    
    # Calculer les IPs dynamiquement
    master_ip = f"{subnet}.20"
    replica_ip = f"{subnet}.21"
    new_server_ip = f"{subnet}.22"
    
    dynamic_content = f"""# =============================================================================
# VARIABLES DYNAMIQUES - Générées automatiquement depuis env.conf
# =============================================================================
# NE PAS MODIFIER MANUELLEMENT - Utiliser env.conf à la place
# Script: scripts/generate_ansible_vars.py
# =============================================================================

cert_store_dir: "{{{{ playbook_dir }}/../files/certificat_temp"
reverse_proxy_domain: "{domain}"
domain: "{domain}"
subnet: "{subnet}"

# IPs du cluster PostgreSQL (calculées depuis SUBNET)
master_ip: {master_ip}
replica_ip: {replica_ip}
new_server_ip: {new_server_ip}

# =============================================================================
# FIN DES VARIABLES DYNAMIQUES
# =============================================================================
"""
    
    return dynamic_content

def read_static_part(group_vars_file):
    """Lit la partie statique du fichier (après le marqueur)"""
    
    if not os.path.exists(group_vars_file):
        return ""
    
    with open(group_vars_file, 'r') as f:
        content = f.read()
    
    # Chercher le marqueur de fin des variables dynamiques
    marker = "# FIN DES VARIABLES DYNAMIQUES"
    if marker in content:
        # Retourner tout ce qui est après le marqueur
        idx = content.find(marker) + len(marker)
        return content[idx:].lstrip()
    
    # Si pas de marqueur, retourner le contenu tel quel (première génération)
    return content

def main():
    # Chemins
    script_dir = Path(__file__).parent
    iac_v3_dir = script_dir.parent
    env_file = iac_v3_dir / "env.conf"
    group_vars_file = iac_v3_dir / "ansible" / "group_vars" / "all.yml"
    
    # Vérifier que env.conf existe
    if not env_file.exists():
        print(f"❌ Erreur: {env_file} n'existe pas")
        sys.exit(1)
    
    print(f"📖 Lecture de {env_file}")
    env_vars = parse_env_conf(env_file)
    
    print(f"   DOMAIN={env_vars.get('DOMAIN', 'NON DEFINI')}")
    print(f"   SUBNET={env_vars.get('SUBNET', 'NON DEFINI')}")
    
    # Générer le contenu
    dynamic_part = generate_dynamic_vars(env_vars)
    static_part = read_static_part(group_vars_file)
    
    # Écrire le fichier final
    print(f"\n✏️  Écriture de {group_vars_file}")
    
    # Créer le répertoire si nécessaire
    group_vars_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(group_vars_file, 'w') as f:
        f.write(dynamic_part)
        if static_part:
            f.write("\n")
            f.write(static_part)
    
    print(f"✅ Variables Ansible générées avec succès!")
    print(f"\nVariables dynamiques:")
    print(f"  - domain: {env_vars.get('DOMAIN')}")
    print(f"  - subnet: {env_vars.get('SUBNET')}")
    print(f"  - master_ip: {env_vars.get('SUBNET', '192.168.20')}.20")
    print(f"  - replica_ip: {env_vars.get('SUBNET', '192.168.20')}.21")

if __name__ == "__main__":
    main()
