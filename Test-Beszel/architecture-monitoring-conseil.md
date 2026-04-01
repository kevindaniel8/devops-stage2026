# Architecture Monitoring : Beszel vs Prometheus/Grafana

Guide de décision pour optimiser vos ressources VMs tout en gardant les fonctionnalités essentielles.

---

## 🎯 Votre Problématique

**Contraintes** :
- ✅ Simplicité Beszel (déjà en place)
- ✅ Limitation du nombre de VMs
- ❌ Besoin de HPA (nécessite Prometheus)
- ⚠️ Peur que Prometheus+Grafana soit trop lourd

**Question** : Comment garder la simplicité sans perdre les fonctionnalités K8s ?

---

## 📊 Comparaison des Solutions

### Option 1 : Beszel Seul (Votre setup actuel)

**Avantages** :
- ✅ Ultra-léger (1 VM)
- ✅ Déjà configuré et fonctionnel
- ✅ Simple à maintenir
- ✅ Monitoring système + Docker

**Inconvénients** :
- ❌ Pas de métriques K8s (pods, deployments)
- ❌ Pas de HPA possible
- ❌ Pas de dashboard K8s avancé

**Ressources** : 1 VM (hub) + agents légers

---

### Option 2 : Prometheus + Grafana Complet

**Avantages** :
- ✅ Monitoring K8s natif complet
- ✅ HPA fonctionnel
- ✅ Dashboards avancés
- ✅ Alerting puissant

**Inconvénients** :
- ❌ Lourd (3-4 VMs pour HA)
- ❌ Complexe à configurer
- ❌ Maintenance importante
- ❌ Nécessite stockage long terme

**Ressources** : 3-4 VMs minimum
- 1x Prometheus (+ Alertmanager)
- 1x Grafana
- 1x Thanos/Cortex (pour HA)
- Stockage persistant important

---

### Option 3 : Architecture Hybride Optimisée (RECOMMANDÉ)

**Concept** : Micro-Prometheus intégré à Beszel

```
VM Beszel (192.168.56.13)
├── Beszel Hub (monitoring système)
├── Prometheus léger (métriques K8s)
└── Grafana minimal (dashboards K8s)
    
VM PostgreSQL (192.168.56.22)
├── PostgreSQL (base de données)
├── Beszel Agent (monitoring)
└── K3s/MicroK8s (Kubernetes)
```

---

## 🚀 Solution Optimisée : Beszel + Prometheus Léger

### Architecture Mono-VM (Beszel + Prometheus)

**Sur votre VM Beszel existante (192.168.56.13)** :

```yaml
# docker-compose-beszel-prometheus.yml
version: "3.9"

services:
  # Beszel Hub (déjà existant)
  beszel-server:
    image: henrygd/beszel
    container_name: beszel-server
    ports:
      - "8090:8090"
    volumes:
      - beszel-data:/data
    environment:
      - BESZEL_PORT=8090
    restart: unless-stopped

  # Prometheus léger pour HPA
  prometheus:
    image: prom/prometheus:v2.45.0
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=7d'  # ⭐ LÉGER : 7 jours seulement
      - '--storage.tsdb.retention.size=1GB'  # ⭐ LÉGER : Max 1GB
      - '--web.enable-lifecycle'
    restart: unless-stopped

  # Grafana minimal
  grafana:
    image: grafana/grafana:10.0.0
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana-datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml:ro
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    restart: unless-stopped

volumes:
  beszel-data:
  prometheus-data:
  grafana-data:
```

### Configuration Prometheus Légère

```yaml
# prometheus.yml
scrape_configs:
  # Kubernetes API Server
  - job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
      - role: endpoints
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https

  # Kubernetes Nodes (pour HPA)
  - job_name: 'kubernetes-nodes'
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    kubernetes_sd_configs:
      - role: node
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)

  # Kubernetes Pods (pour HPA)
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
```

### HPA avec Metrics Server

```yaml
# Sur votre K3s/MicroK8s
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: mon-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: mon-app
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

---

## 📊 Consommation Ressources Comparée

| Solution | VMs | RAM | CPU | Stockage | Complexité |
|----------|-----|-----|-----|----------|------------|
| **Beszel seul** | 1 | 512MB | 0.5 | 5GB | ⭐ Simple |
| **Prometheus complet** | 3-4 | 4GB+ | 2+ | 100GB+ | ❌ Complexe |
| **Beszel + Prometheus léger** | 1 | 1GB | 1 | 10GB | ✅ Optimisé |

---

## 🎯 Pourquoi Cette Architecture Hybride ?

### ✅ Avantages :

1. **Une seule VM supplémentaire** (Beszel + Prometheus)
2. **HPA fonctionnel** grâce à Prometheus
3. **Beszel pour le monitoring système** (simple et efficace)
4. **Grafana minimal** pour les dashboards K8s
5. **Prometheus léger** (retention 7j/1GB max)
6. **Pas de perte de simplicité** pour Beszel

### 🔧 Configuration HPA

**Sur votre K3s/MicroK8s (192.168.56.22)** :

```bash
# Installez metrics-server (pour HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Configurez l'endpoint Prometheus
kubectl create configmap prometheus-config \
  --from-literal=prometheus-server=http://192.168.56.13:9090
```

**Créez un HPA** :
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: postgres-hpa  # Exemple pour PostgreSQL
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: postgres
  minReplicas: 1
  maxReplicas: 3
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          averageUtilization: 75
          type: Utilization
```

---

## 🚀 Implémentation Rapide

### Étape 1 : Sur VM Beszel (192.168.56.13)

```bash
# Créez le docker-compose combiné
cd /opt/beszel

# Sauvegardez l'ancien docker-compose-server.yml
cp docker-compose-server.yml docker-compose-server.yml.backup

# Créez le nouveau fichier combiné
cat << 'EOF' > docker-compose-full.yml
# [Contenu du docker-compose ci-dessus]
EOF

# Démarrez tout
docker compose -f docker-compose-full.yml up -d
```

### Étape 2 : Configurez Prometheus

```bash
# Créez le fichier de configuration
sudo tee /opt/beszel/prometheus.yml << 'EOF'
# [Contenu prometheus.yml ci-dessus]
EOF

# Redémarrez Prometheus
docker compose -f docker-compose-full.yml restart prometheus
```

### Étape 3 : Configurez K3s/MicroK8s pour utiliser Prometheus

```bash
# Sur 192.168.56.22 (votre VM PostgreSQL avec K3s)
# Configurez metrics-server pour pointer vers votre Prometheus
kubectl edit configmap -n kube-system metrics-server

# Ajoutez l'endpoint Prometheus externe
```

---

## 🎯 Résumé de la Recommandation

### **Choix : Architecture Hybride Beszel + Prometheus Léger**

**Pourquoi ?**
- 🏆 **1 VM seule** (optimisation ressources)
- 🏆 **HPA fonctionnel** (Prometheus external)
- 🏆 **Simplicité conservée** (Beszel inchangé)
- 🏆 **Coût réduit** (pas de nouvelle VM)

### **Ce que vous gardez** :
- ✅ Beszel (monitoring système simple)
- ✅ PostgreSQL monitoring (déjà en place)
- ✅ Alertes Beszel (déjà configurées)

### **Ce que vous ajoutez** :
- ✅ Prometheus léger (retention courte)
- ✅ Grafana minimal (dashboards K8s)
- ✅ HPA fonctionnel sur K3s/MicroK8s

### **Ce que vous évitez** :
- ❌ Multiplication des VMs
- ❌ Complexité d'un Prometheus complet
- ❌ Coûts d'infrastructure supplémentaires

---

## 📋 Checklist de Migration

- [ ] Sauvegardez la config Beszel actuelle
- [ ] Créez docker-compose-full.yml avec Prometheus
- [ ] Configurez prometheus.yml (léger : 7j/1GB)
- [ ] Déployez sur VM Beszel existante
- [ ] Configurez metrics-server sur K3s/MicroK8s
- [ ] Testez un HPA simple
- [ ] Vérifiez que Beszel fonctionne toujours
- [ ] Configurez dashboards Grafana essentiels

Vous avez le meilleur des deux mondes sans surcharger votre infrastructure ! 🚀

**Alternative** : Si vraiment vous voulez rester ultra-léger, gardez **Beszel seul** et faites du scaling manuel ou utilisez **KEDA** (plus léger que metrics-server pour HPA).
