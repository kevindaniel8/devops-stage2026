# 🚀 Beszel Auto-Setup - Zero Configuration

## ⚡ Installation Ultra-Rapide

### Une seule commande :
```bash
vagrant up
```

C'est tout ! 🎯

---

## 🎯 Ce que vous obtenez automatiquement :

### ✅ Beszel Hub (192.168.56.13)
- **Interface web** : http://192.168.56.13:8090
- **Accès bash** : `docker exec -it beszel-server sh`
- **Outils réseau** : curl, nslookup, dig, ping
- **DNS configuré** : 8.8.8.8/8.8.4.4

### ✅ Agent Local Beszel
- **Monitoring système** : CPU, RAM, disque, réseau
- **Services systemd** : État des services
- **Conteneurs Docker** : Métriques Docker

---

## 🔧 Accès Direct

### Interface Web
```bash
# Navigateur
http://192.168.56.13:8090
```

### Terminal Bash
```bash
# Accès shell au conteneur Beszel
docker exec -it beszel-server sh

# Tests réseau depuis le conteneur
nslookup google.com
ping -c 3 8.8.8.8
curl -I https://google.com
```

---

## 📊 Monitoring Immédiat

Après `vagrant up`, vous avez déjà :

1. **Beszel Hub** fonctionnel
2. **Agent local** connecté
3. **Outils diagnostic** installés
4. **DNS Docker** configuré

---

## 🚨 Prochaines Étapes (Optionnelles)

### Pour ajouter un système distant (ex: PostgreSQL sur 192.168.56.22) :

1. **Créez un token** dans Beszel : http://192.168.56.13:8090/settings/tokens
2. **Cochez "Make permanent"**
3. **Copiez KEY et TOKEN**
4. **Déployez l'agent distant** :

```bash
# Sur la machine distante (192.168.56.22)
mkdir -p /opt/beszel
cat <<EOF > /opt/beszel/docker-compose-agent.yml
services:
  beszel-agent:
    image: henrygd/beszel-agent
    container_name: beszel-agent
    restart: unless-stopped
    privileged: true
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /:/host:ro
      - ./beszel_agent_data:/var/lib/beszel-agent
      - /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket:ro
      - /var/run/systemd/private:/var/run/systemd/private:ro
    environment:
      SERVER: "http://192.168.56.13:8090"
      LISTEN: "45876"
      KEY: "VOTRE_KEY_COPIEE"
      TOKEN: "VOTRE_TOKEN_COPIE"
      HUB_URL: "http://192.168.56.13:8090"
      SYSTEM_NAME: "PostgreSQL-Server"
EOF

docker compose -f docker-compose-agent.yml up -d
```

---

## 🎯 Configuration des Alertes

Dans Beszel : Collections → alerts → New alerts record

### Alertes essentielles :
```json
{
  "system": "ID_POSTGRESQL_SERVER",
  "name": "PostgreSQL Down",
  "value": 1,
  "min": 0
}
```

---

## 🛠️ Commandes Utiles

```bash
# Vérifier l'état des conteneurs
docker ps

# Accès bash Beszel
docker exec -it beszel-server sh

# Logs Beszel
docker logs -f beszel-server

# Redémarrer Beszel
docker restart beszel-server

# Test connectivité depuis Beszel
docker exec beszel-server ping -c 3 192.168.56.22
```

---

## ✅ Vérification Finale

Après `vagrant up`, vérifiez :

```bash
# Beszel accessible ?
curl -I http://192.168.56.13:8090

# Outils installés ?
docker exec beszel-server which nslookup

# Agent connecté ?
# Allez sur http://192.168.56.13:8090
# Vous devriez voir votre système "beszel-Hub"
```

---

**Votre monitoring Beszel est prêt en une seule commande !** 🚀
