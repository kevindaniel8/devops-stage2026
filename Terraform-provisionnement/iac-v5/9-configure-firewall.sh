#!/bin/bash
# =============================================================================
# SCRIPT 9 - Configuration Firewall OPNsense via API
# =============================================================================
# Usage: ./9-configure-firewall.sh [aliases|rules|nat|all]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.conf"

# Charger les clés API depuis le fichier externe (si existe)
if [[ -f "${FIREWALL_API_KEYS_FILE}" ]]; then
    source "${FIREWALL_API_KEYS_FILE}"
fi

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err() { echo -e "${RED}[ERR]${NC} $*"; }

# API Function
opn_api() {
    local method="$1" endpoint="$2" data="${3:-}"
    # Si on est sur OPNsense (localhost), utiliser localhost, sinon utiliser WAN_IP
    if [[ -f /usr/local/opnsense/version ]]; then
        local url="https://127.0.0.1/api/${endpoint}"
    else
        local url="https://${FIREWALL_WAN_IP}/api/${endpoint}"
    fi
    local auth="${FIREWALL_API_KEY}:${FIREWALL_API_SECRET}"
    
    if [[ -n "$data" ]]; then
        curl -sk -u "$auth" -X "$method" -H "Content-Type: application/json" -d "$data" "$url"
    else
        curl -sk -u "$auth" -X "$method" -H "Content-Type: application/json" "$url"
    fi
}

# Check prerequisites
check_api() {
    log_info "Verification API OPNsense..."
    
    if [[ -z "$FIREWALL_API_KEY" ]] || [[ -z "$FIREWALL_API_SECRET" ]]; then
        log_err "Cles API non configurees!"
        echo ""
        echo "📋 Etapes pour generer les cles API:"
        echo "   1. Connectez-vous a https://${FIREWALL_WAN_IP}"
        echo "   2. System > Access > API"
        echo "   3. Activer 'Legacy API' si necessaire"
        echo "   4. Click 'Generate new API keys'"
        echo "   5. Copier key et secret dans env.conf"
        echo ""
        exit 1
    fi
    
    # Test API
    if opn_api GET "core/firmware/status" | grep -q "product_version"; then
        log_ok "Connexion API OK"
    else
        log_warn "Test API a echoue - verifiez les cles"
    fi
}

# Create Alias
create_alias() {
    local name="$1" type="$2" content="$3"
    log_info "Creation alias: $name"
    
    local json="{\"alias\":{\"enabled\":\"1\",\"name\":\"$name\",\"type\":\"$type\",\"content\":\"$content\",\"description\":\"Auto-generated\"}}"
    opn_api POST "firewall/alias/addItem" "$json" > /dev/null 2>&1 || true
}

# Create all aliases
create_aliases() {
    log_info "=== CREATION DES ALIAS ==="
    
    create_alias "INFRA_MGMT" "host" "192.168.20.2"
    create_alias "DEV_NETWORK" "network" "192.168.0.0/24"
    create_alias "INFRA_DATABASE" "host" "192.168.20.20 192.168.20.21"
    create_alias "INFRA_K8S_CONTROL" "host" "192.168.20.220"
    create_alias "INFRA_K8S_WORKERS" "host" "192.168.20.221 192.168.20.222"
    create_alias "INFRA_K8S_ALL" "network" "192.168.20.220/29"
    create_alias "INFRA_ALL_SERVERS" "network" "192.168.20.0/24"
    create_alias "INFRA_NAS" "host" "192.168.20.5"
    create_alias "INFRA_NEXTCLOUD" "host" "192.168.20.10"
    create_alias "INFRA_REVERSE_PROXY" "host" "192.168.20.3"
    create_alias "INFRA_HARBOR" "host" "192.168.20.205"
    create_alias "INFRA_WIKIJS" "host" "192.168.20.4"
    create_alias "INFRA_OPENPROJECT" "host" "192.168.20.4"
    create_alias "INFRA_MAILSERVER" "host" "192.168.20.3"
    
    # Apply changes
    opn_api POST "firewall/alias/reconfigure" "{}" > /dev/null 2>&1 || true
    log_ok "Alias crees"
}

# Create firewall rule
create_rule() {
    local seq="$1" src="$2" dst="$3" proto="$4" port="$5" desc="$6"
    
    local json="{\"rule\":{\"enabled\":\"1\",\"sequence\":\"$seq\",\"action\":\"pass\",\"interface\":\"${FIREWALL_LAN_IF}\",\"ipprotocol\":\"inet\",\"protocol\":\"$proto\",\"source_net\":\"$src\",\"destination_net\":\"$dst\",\"destination_port\":\"$port\",\"descr\":\"$desc\"}}"
    
    opn_api POST "firewall/filter/addRule" "$json" > /dev/null 2>&1 || true
}

# Create LAN rules
create_lan_rules() {
    log_info "=== CREATION REGLES LAN ==="
    
    create_rule "1" "INFRA_MGMT" "INFRA_ALL_SERVERS" "any" "" "Management -> All"
    create_rule "2" "INFRA_ALL_SERVERS" "INFRA_ALL_SERVERS" "tcp" "22" "SSH interne"
    create_rule "3" "INFRA_K8S_ALL" "INFRA_DATABASE" "tcp" "5432" "K8s -> PostgreSQL"
    create_rule "4" "INFRA_DATABASE" "INFRA_DATABASE" "tcp" "5432" "Replication PG"
    create_rule "5" "INFRA_K8S_ALL" "INFRA_K8S_ALL" "any" "" "K8s inter-node"
    create_rule "6" "INFRA_ALL_SERVERS" "INFRA_NAS" "tcp" "2049,445" "NAS NFS/SMB"
    
    # Apply
    opn_api POST "firewall/filter/apply" "{}" > /dev/null 2>&1 || true
    log_ok "Regles LAN crees"
}

# Create routing rules between networks (inter-VLAN)
create_routing_rules() {
    log_info "=== CREATION REGLES DE ROUTAGE INTER-VLAN ==="
    log_info "Autorise SSH depuis le reseau de dev (192.168.0.0/24) vers VMs (192.168.20.0/24)"
    
    # Regle pour SSH depuis DEV_NETWORK vers INFRA_ALL_SERVERS via WAN interface
    # Cette regle permet le routage entre WAN (192.168.0.0/24) et LAN (192.168.20.0/24)
    local json
    json='{"rule":{"enabled":"1","sequence":"1","action":"pass","quick":"1","interface":"'${FIREWALL_WAN_IF}'","ipprotocol":"inet","protocol":"tcp","source_net":"DEV_NETWORK","destination_net":"INFRA_ALL_SERVERS","destination_port":"22","descr":"SSH: Dev Network -> Infrastructure VMs","log":"1"}}'
    opn_api POST "firewall/filter/addRule" "$json" > /dev/null 2>&1 || true
    
    # Regle pour ICMP (ping) depuis DEV_NETWORK vers INFRA_ALL_SERVERS
    json='{"rule":{"enabled":"1","sequence":"2","action":"pass","quick":"1","interface":"'${FIREWALL_WAN_IF}'","ipprotocol":"inet","protocol":"icmp","source_net":"DEV_NETWORK","destination_net":"INFRA_ALL_SERVERS","descr":"ICMP: Dev Network -> Infrastructure VMs (ping)","log":"0"}}'
    opn_api POST "firewall/filter/addRule" "$json" > /dev/null 2>&1 || true
    
    # Regle pour HTTPS/HTTP vers Reverse Proxy depuis DEV_NETWORK
    json='{"rule":{"enabled":"1","sequence":"3","action":"pass","quick":"1","interface":"'${FIREWALL_WAN_IF}'","ipprotocol":"inet","protocol":"tcp","source_net":"DEV_NETWORK","destination_net":"INFRA_NEXTCLOUD","destination_port":"80,443","descr":"HTTP/HTTPS: Dev Network -> Reverse Proxy","log":"1"}}'
    opn_api POST "firewall/filter/addRule" "$json" > /dev/null 2>&1 || true
    
    # Appliquer les changements
    opn_api POST "firewall/filter/apply" "{}" > /dev/null 2>&1 || true
    log_ok "Regles de routage inter-VLAN crees"
}

# Create NAT rule
create_nat() {
    log_info "=== CREATION REGLES NAT ==="

    # NAT HTTP -> Reverse Proxy
    local json='{"nat":{"interface":"wan","protocol":"tcp","source":"any","destination":"wanip","target":"192.168.20.3","local-port":"80","descr":"HTTP to Reverse Proxy"}}'
    opn_api POST "firewall/nat/addPortForward" "$json" > /dev/null 2>&1 || true

    # NAT HTTPS
    json='{"nat":{"interface":"wan","protocol":"tcp","source":"any","destination":"wanip","target":"192.168.20.3","local-port":"443","descr":"HTTPS to Reverse Proxy"}}'
    opn_api POST "firewall/nat/addPortForward" "$json" > /dev/null 2>&1 || true

    opn_api POST "firewall/nat/apply" "{}" > /dev/null 2>&1 || true
    log_ok "NAT crees"
}

# Export config for manual import
export_config() {
    log_info "=== EXPORT CONFIGURATION ==="
    
    local outdir="${SCRIPT_DIR}/firewall-config"
    mkdir -p "$outdir"
    
    # Aliases CSV
    cat > "$outdir/aliases.csv" <<EOF
Name,Type,Content,Description
DEV_NETWORK,network,192.168.0.0/24,Reseau de developpement (poste dev)
INFRA_MGMT,host,192.168.20.2,Management station
INFRA_DATABASE,host,192.168.20.20 192.168.20.21,PostgreSQL servers
INFRA_K8S_CONTROL,host,192.168.20.220,K8s Control Plane
INFRA_K8S_WORKERS,host,192.168.20.221 192.168.20.222,K8s Workers
INFRA_K8S_ALL,network,192.168.20.220/29,All K8s nodes
INFRA_ALL_SERVERS,network,192.168.20.0/24,All infrastructure
INFRA_NAS,host,192.168.20.5,NAS TrueNAS
INFRA_NEXTCLOUD,host,192.168.20.10,Nextcloud
INFRA_REVERSE_PROXY,host,192.168.20.3,Reverse Proxy
INFRA_HARBOR,host,192.168.20.205,Harbor Registry
INFRA_WIKIJS,host,192.168.20.4,WikiJS
INFRA_OPENPROJECT,host,192.168.20.4,OpenProject
INFRA_MAILSERVER,host,192.168.20.3,Mailserver
EOF

    # Rules CSV
    cat > "$outdir/rules.csv" <<EOF
Action,Interface,Source,Destination,Protocol,Port,Description
pass,lan,INFRA_MGMT,INFRA_ALL_SERVERS,any,any,Management -> All
pass,lan,INFRA_ALL_SERVERS,INFRA_ALL_SERVERS,tcp,22,SSH interne
pass,lan,INFRA_K8S_ALL,INFRA_DATABASE,tcp,5432,K8s -> PostgreSQL
pass,lan,INFRA_DATABASE,INFRA_DATABASE,tcp,5432,Replication PG
pass,lan,INFRA_K8S_ALL,INFRA_K8S_ALL,any,any,K8s inter-node
pass,lan,INFRA_ALL_SERVERS,INFRA_NAS,tcp,"2049,445",NAS access
pass,wan,DEV_NETWORK,INFRA_ALL_SERVERS,tcp,22,SSH depuis reseau dev
pass,wan,DEV_NETWORK,INFRA_ALL_SERVERS,icmp,,Ping depuis reseau dev
pass,wan,DEV_NETWORK,INFRA_REVERSE_PROXY,tcp,"80,443",HTTP/HTTPS vers Reverse Proxy
pass,wan,DEV_NETWORK,INFRA_HARBOR,tcp,"80,443",HTTP/HTTPS vers Harbor
pass,wan,DEV_NETWORK,INFRA_WIKIJS,tcp,3000,WikiJS
pass,wan,DEV_NETWORK,INFRA_OPENPROJECT,tcp,8080,OpenProject
pass,wan,DEV_NETWORK,INFRA_NEXTCLOUD,tcp,"80,443",Nextcloud
EOF

    log_ok "Configuration exportee dans $outdir/"
    ls -la "$outdir/"
}

# Show usage
usage() {
    cat <<EOF
Usage: $0 [command]

Commands:
  check      - Verifier la connexion API
  aliases    - Creer les alias reseau
  rules      - Creer les regles LAN
  routing    - Creer les regles de routage inter-VLAN
  nat        - Creer les regles NAT
  export     - Exporter la configuration (CSV)
  all        - Executer tout (aliases + rules + routing + nat)
  help       - Afficher cette aide

Exemples:
  $0 check          # Tester la connexion API
  $0 aliases        # Creer uniquement les alias
  $0 all            # Configurer tout automatiquement
  $0 export         # Generer fichiers CSV pour import manuel

Configuration:
  Editer env.conf pour definir:
    - FIREWALL_API_KEY
    - FIREWALL_API_SECRET
    - FIREWALL_WAN_IP (defaut: 192.168.0.50)
    - FIREWALL_LAN_IF (defaut: lan)
EOF
}

# Main
case "${1:-help}" in
    check)
        check_api
        ;;
    aliases)
        check_api
        create_aliases
        ;;
    rules)
        check_api
        create_lan_rules
        ;;
    routing)
        check_api
        create_routing_rules
        ;;
    nat)
        check_api
        create_nat
        ;;
    all)
        check_api
        create_aliases
        create_lan_rules
        create_routing_rules
        create_nat
        log_ok "Configuration firewall terminee!"
        ;;
    export)
        export_config
        ;;
    help|*)
        usage
        ;;
esac
