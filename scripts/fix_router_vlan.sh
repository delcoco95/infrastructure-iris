#!/bin/bash
set -e

# 1. Interface parente UP
ip link set enp0s8 up

# 2. Module 8021q
modprobe 8021q
echo "8021q" > /etc/modules-load.d/vlan.conf

# 3. Installer vlan (rapide, pas de prompt)
DEBIAN_FRONTEND=noninteractive apt-get install -y -q vlan 2>&1 | tail -5

# 4. Créer les interfaces VLAN
for vlan in 10 20 30 40 50 99; do
  ip link del "vlan${vlan}" 2>/dev/null || true
  ip link add link enp0s8 name "vlan${vlan}" type vlan id ${vlan}
  ip link set "vlan${vlan}" up
done
ip addr add 192.168.10.1/24 dev vlan10 2>/dev/null || true
ip addr add 192.168.20.1/24 dev vlan20 2>/dev/null || true
ip addr add 192.168.30.1/24 dev vlan30 2>/dev/null || true
ip addr add 192.168.40.1/24 dev vlan40 2>/dev/null || true
ip addr add 192.168.50.1/24 dev vlan50 2>/dev/null || true
ip addr add 192.168.99.1/24 dev vlan99 2>/dev/null || true

# 5. IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-forward.conf

# 6. Résultat
echo ""
echo "=== VLAN Interfaces ==="
ip addr | grep -E "(vlan|inet 192)"
echo ""
echo "=== Forwarding ==="
cat /proc/sys/net/ipv4/ip_forward
echo ""
echo "=== Routes ==="
ip route