#!/usr/bin/env bash
# ============================================================
# linux_docker_services.sh — Provisioning VM Ubuntu + Docker
# Projet : IRIS-NICE-2024-RP01
# Auteur  : Nedjmeddine Belloum
# VM      : SRV-LINUX-IRIS — Ubuntu 22.04 LTS — 192.168.50.20
#
# Services déployés :
#   - GLPI       (gestion de parc — port 8082)
#   - Nextcloud  (stockage partagé — port 8081)
#   - WireGuard  (VPN admin — port 51820/51821)
#   - Prometheus (métriques — port 9090)
#   - Grafana    (dashboards — port 3000)
#   - Node Exporter (métriques OS — port 9100)
#   - CAdvisor   (métriques Docker — port 8083)
#   - ClamAV     (antivirus — port 3310)
# ============================================================

set -euo pipefail

log() { echo "[$(date '+%H:%M:%S')] $*"; }
err() { echo "[ERREUR] $*" >&2; exit 1; }

log "=== Provisioning SRV-LINUX-IRIS ==="

# ── 1. Mise à jour système ────────────────────────────────
log "[1/6] Mise à jour du système..."
apt-get update -y
apt-get upgrade -y

# ── 2. Installation des dépendances ──────────────────────
log "[2/6] Installation des outils..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    ufw \
    nftables \
    htop \
    net-tools \
    vim \
    git

# ── 3. Installation Docker CE ─────────────────────────────
log "[3/6] Installation de Docker CE..."
if ! command -v docker &>/dev/null; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    log "[OK] Docker installé."
else
    log "[SKIP] Docker déjà installé."
fi

usermod -aG docker vagrant 2>/dev/null || true

# ── 4. Configuration pare-feu UFW ────────────────────────
log "[4/6] Configuration pare-feu UFW..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Administration
ufw allow from 10.0.2.0/24   to any port 22 proto tcp comment 'SSH — Vagrant NAT (lab uniquement)'
ufw allow from 192.168.50.0/24 to any port 22 proto tcp comment 'SSH — Management uniquement'

# Services applicatifs (accessibles depuis LAN interne)
ufw allow from 192.168.50.0/24 to any port 8081 proto tcp comment 'Nextcloud'
ufw allow from 192.168.50.0/24 to any port 8082 proto tcp comment 'GLPI'
ufw allow from 192.168.50.0/24 to any port 3000 proto tcp comment 'Grafana'
ufw allow from 192.168.50.0/24 to any port 9090 proto tcp comment 'Prometheus'
ufw allow from 192.168.50.0/24 to any port 9100 proto tcp comment 'Node Exporter'
ufw allow from 192.168.50.0/24 to any port 8083 proto tcp comment 'CAdvisor'

# WireGuard (accessible depuis Internet pour accès distant)
ufw allow 51820/udp  comment 'WireGuard VPN'
ufw allow 51821/tcp  comment 'WireGuard Web UI (management uniquement)'

# ClamAV (réseau interne)
ufw allow from 192.168.50.0/24 to any port 3310 proto tcp comment 'ClamAV'

ufw --force enable
log "[OK] UFW configuré."

# ── 5. Création de la structure de données Docker ────────
log "[5/6] Création des volumes Docker..."
mkdir -p /opt/iris/{nextcloud-data,nextcloud-db,glpi-data,glpi-db,grafana-data,prometheus-data,wireguard-data,clamav-db}
chown -R 1000:1000 /opt/iris/nextcloud-data
chown -R 472:472   /opt/iris/grafana-data       # Grafana UID=472
chown -R 65534:65534 /opt/iris/prometheus-data  # Prometheus UID=65534 (nobody)
log "[OK] Volumes créés dans /opt/iris/"

# Copie du fichier .env depuis /vagrant si présent
if [ -f /vagrant/.env ]; then
    cp /vagrant/.env /opt/iris/.env
    log "[OK] Fichier .env copié."
else
    log "[WARN] Fichier .env absent — utilisation des valeurs par défaut."
fi

# ── 6. Démarrage des services Docker ─────────────────────
log "[6/6] Docker Compose prêt — démarrage manuel requis"
log ""
log "Pour démarrer les conteneurs, SSH dans la VM et exécuter :"
log "  cd /vagrant && docker compose up -d"
log ""
log "Note : le pull des images (~3 Go) peut prendre 10-20 min selon la bande passante."
log "       Lance-le manuellement APRES le provisioning pour éviter le timeout SSH."
if [ ! -f /vagrant/docker-compose.yml ]; then
    err "docker-compose.yml introuvable dans /vagrant. Vérifier le Vagrantfile."
fi

log ""
log "=== Provisioning terminé ==="
log ""
log "Services disponibles (depuis VLAN 50 Management) :"
log "  Nextcloud  : http://192.168.50.20:8081"
log "  GLPI       : http://192.168.50.20:8082"
log "  Grafana    : http://192.168.50.20:3000"
log "  Prometheus : http://192.168.50.20:9090"
log "  WireGuard  : http://192.168.50.20:51821"
log ""
log "Intégration AD (à configurer manuellement après déploiement AD) :"
log "  LDAP Server : ldap://192.168.50.10:389"
log "  Base DN     : dc=mediaschool,dc=local"
log "  Bind DN     : CN=svc_nps,OU=CompteService,OU=Serveurs,DC=mediaschool,DC=local"
