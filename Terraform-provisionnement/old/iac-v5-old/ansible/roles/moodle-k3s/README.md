# ArgoCD Role

Déploiement d'ArgoCD sur cluster K3s avec exposition via Ingress (domaine) et NodePort (IP directe).

## Description

Ce rôle installe et configure ArgoCD avec :
- Namespace dédié `argocd`
- Ingress pour accès via nom de domaine (`argo.{{ domain }}`)
- Service NodePort pour accès direct par IP (`http://IP:30080`)
- HTTPS désactivé (HTTP uniquement pour dev/test)

## Accès

| Méthode | URL | Description |
|---------|-----|-------------|
| IP Directe | `http://192.168.20.220:30080` | Accès développement (sans DNS) |
| Domaine | `https://argo.greencontracts.lan` | Accès production (via Ingress) |

## Variables

### defaults/main.yml

```yaml
argocd_namespace: argocd                    # Namespace Kubernetes
argocd_manifest_url: "https://raw.githubusercontent.com/..."  # Manifest officiel
argocd_domain: "argo.{{ domain | default('greencontracts.lan') }}"  # URL d'accès
argocd_enable_ip_access: true               # Activer l'accès par IP
argocd_ip: "{{ ansible_host }}"            # IP du nœud (pour affichage)
```

### Variables globales (group_vars/all.yml)

```yaml
domain: "greencontracts.lan"               # Utilisé par argocd_domain
```

## Utilisation

### Déploiement

```bash
cd ansible
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy-argocd.yml
```

### Récupérer le mot de passe admin

```bash
ssh ubuntu@192.168.20.220 \
  "sudo k3s kubectl get secret argocd-initial-admin-secret -n argocd \
   -o jsonpath='{.data.password}' | base64 -d"
```

**Login par défaut :**
- Username: `admin`
- Password: *(voir commande ci-dessus)*

## Structure

```
argocd/
├── defaults/
│   └── main.yml          # Variables par défaut
├── tasks/
│   └── main.yml          # Tâches de déploiement
├── templates/
│   └── ingress-argocd.old.yaml  # (déprécié)
└── README.md             # Ce fichier
```

## Tâches principales

1. **Création namespace** `argocd`
2. **Téléchargement** du manifest officiel ArgoCD
3. **Installation** des composants ArgoCD
4. **Configuration** ConfigMap `argocd-cmd-params-cm` (HTTP insecure)
5. **Ingress** pour accès domaine (`argo.greencontracts.lan`)
6. **NodePort** pour accès direct IP (`:30080`)

## Dépannage

### Vérifier les pods
```bash
sudo k3s kubectl get pods -n argocd
```

### Vérifier le service
```bash
sudo k3s kubectl get svc argocd-server -n argocd
```

### Logs ArgoCD
```bash
sudo k3s kubectl logs -n argocd deployment/argocd-server
```

## Notes

- Le HTTPS est désactivé (`server.insecure: "true"`) pour simplifier l'accès dev
- En production, activer HTTPS via Traefik/LetsEncrypt
- Le NodePort `30080` est dans la plage valide (30000-32767)
- Le domaine est défini dans `env.conf` → généré dans `group_vars/all.yml`
