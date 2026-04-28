#!/bin/bash
sudo cp /vagrant/scripts/50-vlan-router.yaml /etc/netplan/50-vlan-router.yaml
sudo chmod 600 /etc/netplan/50-vlan-router.yaml
echo "[OK] Netplan persistant configure"
echo ""
echo "=== Ping DC 192.168.50.10 ==="
ping -c 3 -W 2 192.168.50.10 && echo "[OK] DC joignable" || echo "[FAIL] DC non joignable"
echo ""
echo "=== Ping SW2-IRIS 192.168.50.2 ==="
ping -c 3 -W 2 192.168.50.2 && echo "[OK] Switch joignable" || echo "[FAIL] Switch non joignable"