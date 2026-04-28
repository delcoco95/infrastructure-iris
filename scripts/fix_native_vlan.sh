#!/bin/bash
# VLAN 50 = native VLAN sur Gi0/1 => frames NON-taguees => sur enp0s8 directement
sudo ip addr del 192.168.50.1/24 dev vlan50 2>/dev/null || true
sudo ip link set vlan50 down 2>/dev/null || true
sudo ip link del vlan50 2>/dev/null || true

# Assigner 192.168.50.1 sur enp0s8 directement
sudo ip addr add 192.168.50.1/24 dev enp0s8 2>/dev/null || true

echo "=== Config actuelle ==="
ip addr show enp0s8 | grep inet
ip addr show | grep "vlan"

echo ""
echo "=== Ping DC 192.168.50.10 ==="
ping -c 3 -W 2 192.168.50.10 && echo "[OK] DC joignable" || echo "[FAIL] DC non joignable"
echo ""
echo "=== Ping SW2-IRIS 192.168.50.2 ==="
ping -c 3 -W 2 192.168.50.2 && echo "[OK] Switch joignable" || echo "[FAIL] Switch non joignable"