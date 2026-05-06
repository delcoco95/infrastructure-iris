#!/usr/bin/env bash
# ============================================================
# router_vlan.sh — VM Routeur IRIS (remplace RT2-IRIS)
# Projet : IRIS-NICE-2026-RP01
# Auteur  : Nedjmeddine Belloum
#
# Ce script configure la VM comme routeur inter-VLAN via
# le trunk SW2-IRIS Gi0/1 (native VLAN 50 + tagged 10/20/30/40/99)
#
# Topologie :
#   enp0s3  = NIC1 NAT (Vagrant SSH, internet host)
#   enp0s8  = NIC2 Bridged sur USB2.0 Ethernet (trunk physique)
#   enp0s8.10 = 192.168.10.1/24  (GW VLAN 10 Étudiants)
#   enp0s8.20 = 192.168.20.1/24  (GW VLAN 20 Profs)
#   enp0s8.30 = 192.168.30.1/24  (GW VLAN 30 Administration)
#   enp0s8.40 = 192.168.40.1/24  (GW VLAN 40 Invités)
#   enp0s8.50 = 192.168.50.1/24  (GW VLAN 50 Management — = RT2-IRIS)
#   enp0s8.99 = 192.168.99.1/24  (GW VLAN 99 PRE_AUTH)
# ============================================================

set -euo pipefail
log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "=== Provisioning VM-ROUTEUR-IRIS ==="

# ── 1. Identifier l'interface bridgée (NIC2) ─────────────
# Dans VirtualBox Ubuntu Jammy, NIC1=enp0s3, NIC2=enp0s8
TRUNK_IF=""
for iface in enp0s8 eth1 enp0s9; do
    if ip link show "$iface" &>/dev/null; then
        TRUNK_IF="$iface"
        break
    fi
done

if [ -z "$TRUNK_IF" ]; then
    # Fallback : prendre la seconde interface (hors lo et NIC1)
    TRUNK_IF=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$\|^enp0s3$\|^eth0$' | head -1)
fi

log "Interface trunk détectée : $TRUNK_IF"

# ── 2. Installer les dépendances ─────────────────────────
log "[1/5] Installation des paquets..."
apt-get update -qq
apt-get install -y -qq \
    vlan \
    isc-dhcp-relay \
    net-tools \
    tcpdump \
    iproute2 \
    iptables-persistent

# ── 3. Activer le module 8021q (VLAN tagging) ────────────
log "[2/5] Activation du module 802.1Q..."
modprobe 8021q
echo "8021q" >> /etc/modules-load.d/vlan.conf

# ── 4. Activer le routage IP permanent ───────────────────
log "[3/5] Activation du routage IP..."
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-ip-forward.conf
sysctl -p /etc/sysctl.d/99-ip-forward.conf

# ── 5. Configurer les interfaces via netplan ─────────────
log "[4/5] Configuration des interfaces VLAN (netplan)..."

cat > /etc/netplan/50-vlan-router.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${TRUNK_IF}:
      # Interface trunk physique.
      # Native VLAN 50 sur SW2-IRIS Gi0/1 = trames VLAN 50 arrivent NON-taguees.
      # => IP 192.168.50.1 sur l'interface parent, PAS sur une sous-interface vlan50.
      # => Les autres VLANs (10/20/30/40/99) sont tagged => sous-interfaces dédiées.
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [192.168.50.1/24]
  vlans:
    vlan10:
      id: 10
      link: ${TRUNK_IF}
      addresses: [192.168.10.1/24]
      dhcp4: false
    vlan20:
      id: 20
      link: ${TRUNK_IF}
      addresses: [192.168.20.1/24]
      dhcp4: false
    vlan30:
      id: 30
      link: ${TRUNK_IF}
      addresses: [192.168.30.1/24]
      dhcp4: false
    vlan40:
      id: 40
      link: ${TRUNK_IF}
      addresses: [192.168.40.1/24]
      dhcp4: false
    vlan99:
      id: 99
      link: ${TRUNK_IF}
      addresses: [192.168.99.1/24]
      dhcp4: false
EOF
# NOTE : vlan50 supprimé intentionnellement.
# VLAN 50 = native VLAN sur Gi0/1 => frames non-taguées => IP sur ${TRUNK_IF} directement.

# Appliquer la configuration netplan
netplan apply || true
log "Netplan appliqué."

# Attendre que les interfaces soient up
sleep 3

# ── 6. Configurer le DHCP Relay ──────────────────────────
log "[5/5] Configuration du DHCP Relay (→ DC 192.168.50.10)..."

# Configurer isc-dhcp-relay pour relayer vers le DC
cat > /etc/default/isc-dhcp-relay << 'RELAYEOF'
# Serveur DHCP cible = DC-IRIS-01
SERVERS="192.168.50.10"
# Interfaces sur lesquelles écouter les requêtes DHCP des clients
INTERFACES="vlan10 vlan20 vlan30 vlan40 vlan50 vlan99"
# Options supplémentaires
OPTIONS="-a"
RELAYEOF

systemctl enable isc-dhcp-relay
systemctl restart isc-dhcp-relay

# ── 7. iptables — NAT optionnel via NIC1 (internet) ──────
# Si le PC hôte a internet via WiFi (NIC1 Vagrant NAT) :
# Activer le NAT pour que les clients VLAN aient internet
iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE
iptables -A FORWARD -i enp0s3 -o vlan10 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -o enp0s3 -j ACCEPT

# Sauvegarder les règles iptables (persistence)
netfilter-persistent save

# ── 8. Vérifications ─────────────────────────────────────
log "=== Vérifications finales ==="
log "Interfaces configurées :"
ip addr show vlan50  2>/dev/null | grep "inet " || log "  [WARN] vlan50 pas encore up"
ip addr show vlan10  2>/dev/null | grep "inet " || log "  [WARN] vlan10 pas encore up"

log "Routage IP :"
sysctl net.ipv4.ip_forward

log "DHCP Relay :"
systemctl is-active isc-dhcp-relay && log "  [OK] dhcp-relay actif" || log "  [WARN] dhcp-relay inactif"

log ""
log "=== VM-ROUTEUR-IRIS configurée avec succès ==="
log ""
log "Accès SSH : vagrant ssh vm-routeur"
log "Vérifier : ip addr | grep 'inet 192'"
log "Vérifier : ip route"
log ""
