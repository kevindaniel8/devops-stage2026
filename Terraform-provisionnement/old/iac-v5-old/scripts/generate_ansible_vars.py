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
    domain = env_vars.get('DOMAIN', 'greencontracts.lan')
    
    # Variables TLS depuis env.conf
    tls_mode = env_vars.get('TLS_MODE', 'mixed')
    ca_common_name = env_vars.get('CA_COMMON_NAME', 'GreenContracts-Root-CA')
    ca_validity_days = env_vars.get('CA_VALIDITY_DAYS', '3650')
    cert_validity_days = env_vars.get('CERT_VALIDITY_DAYS', '365')
    cert_key_size = env_vars.get('CERT_KEY_SIZE', '4096')
    letsencrypt_email = env_vars.get('LETSENCRYPT_EMAIL', f'admin@{domain}')
    letsencrypt_staging = env_vars.get('LETSENCRYPT_STAGING', 'false')
    
    # Calculer les IPs dynamiquement
    master_ip = f"{subnet}.20"
    replica_ip = f"{subnet}.21"
    new_server_ip = f"{subnet}.22"
    
    # Générer les sous-domaines dynamiquement
    subdomains = {
        'proxy': f'proxy.{domain}',
        'moodle': f'moodle.{domain}',
        'argocd': f'argocd.{domain}',
        'wikijs': f'wikijs.{domain}',
        'openproject': f'openproject.{domain}',
        'nextcloud': f'nextcloud.{domain}',
        'mail': f'mail.{domain}',
        'harbor': f'harbor.{domain}',
        'beszel': f'beszel.{domain}',
        'ca': f'ca.{domain}',
    }
    
    # Extraire le nom de domaine sans extension pour Samba
    domain_name = domain.split('.')[0] if '.' in domain else domain
    samba_realm = domain.upper().replace('.', '')
    
    dynamic_content = f"""# =============================================================================
# VARIABLES DYNAMIQUES - Générées automatiquement depuis env.conf
# =============================================================================
# NE PAS MODIFIER MANUELLEMENT - Utiliser env.conf à la place
# Script: scripts/generate_ansible_vars.py
# =============================================================================

# Domaine principal
domain: "{domain}"
reverse_proxy_domain: "{domain}"
main_domain: "{domain}"
subnet: "{subnet}"

# Sous-domaines (générés automatiquement depuis le domaine principal)
proxy_fqdn: "{subdomains['proxy']}"
moodle_fqdn: "{subdomains['moodle']}"
argocd_fqdn: "{subdomains['argocd']}"
wikijs_fqdn: "{subdomains['wikijs']}"
openproject_fqdn: "{subdomains['openproject']}"
nextcloud_fqdn: "{subdomains['nextcloud']}"
mail_fqdn: "{subdomains['mail']}"
harbor_fqdn: "{subdomains['harbor']}"
beszel_fqdn: "{subdomains['beszel']}"
ca_fqdn: "{subdomains['ca']}"

# Variables Samba AD (générées depuis le domaine)
samba_domain: "{domain_name}"
samba_realm: "{samba_realm}"

# Variables SSL/TLS (depuis env.conf)
tls_mode: "{tls_mode}"
ca_common_name: "{ca_common_name}"
ca_validity_days: {ca_validity_days}
cert_validity_days: {cert_validity_days}
cert_key_size: {cert_key_size}
letsencrypt_email: "{letsencrypt_email}"
letsencrypt_staging: {letsencrypt_staging}

# Certificats
cert_store_dir: "{{{{ playbook_dir }}/../files/certificat_temp"

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
