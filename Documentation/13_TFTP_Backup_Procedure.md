# 13 — Procédure de Sauvegarde TFTP Cisco
**Projet :** IRIS-NICE-2024-RP01  
**Date :** 2025-01  
**Auteur :** Nedjmeddine Belloum  
**Équipements :** SW2-IRIS, AP2-IRIS, RT2-IRIS

---

## Architecture TFTP

```
srv-linux (192.168.50.20)
├── tftpd-hpa (port UDP 69)
├── /srv/tftp/
│   └── cisco-backups/
│       ├── SW2-IRIS/       ← Sauvegardes SW2-IRIS
│       ├── AP2-IRIS/       ← Sauvegardes AP2-IRIS
│       ├── RT2-IRIS/       ← Sauvegardes RT2-IRIS
│       └── archives/       ← Fichiers > 7 jours
└── cron → cisco-tftp-backup.sh (02h00 chaque nuit)
```

---

## Déploiement initial

### Sur srv-linux (via Vagrant ou SSH)
```bash
# Via Vagrant (si VM non démarrée) :
vagrant ssh srv-linux

# Puis :
sudo bash /vagrant/scripts/10_configure_tftp.sh
```

### Méthodes de sauvegarde (ordre de priorité)
1. **SNMP** — Déclenche automatiquement une copie vers TFTP
2. **SSH** — `show running-config` récupéré via SSH
3. **Manuel** — Commande depuis l'équipement Cisco

---

## Configuration des équipements Cisco

### SW2-IRIS
```
conf t
 snmp-server community iris-ro RO 99
 snmp-server community iris-rw RW 99
 snmp-server host 192.168.50.20 version 2c iris-ro
 ip tftp source-interface Vlan50
end

! Sauvegarde manuelle immédiate :
copy running-config tftp://192.168.50.20/cisco-backups/SW2-IRIS/SW2-IRIS_manual.cfg
```

### AP2-IRIS
```
conf t
 snmp-server community iris-ro RO
 snmp-server host 192.168.50.20 version 2c iris-ro
end

copy running-config tftp://192.168.50.20/cisco-backups/AP2-IRIS/AP2-IRIS_manual.cfg
```

### RT2-IRIS
```
conf t
 snmp-server community iris-ro RO 99
 snmp-server community iris-rw RW 99
 snmp-server host 192.168.50.20 version 2c iris-ro
 ip tftp source-interface FastEthernet0/0.50
end

! Sauvegarde manuelle immédiate :
copy running-config tftp://192.168.50.20/cisco-backups/RT2-IRIS/RT2-IRIS_manual.cfg
```

---

## Planification des sauvegardes

| Type | Fréquence | Heure | Rétention |
|------|-----------|-------|-----------|
| Quotidienne | Tous les jours | 02h00 | 7 jours en actif |
| Archivage | Auto (>7 jours) | — | 30 jours dans `archives/` |
| Hebdomadaire | Dimanche | 03h00 | Copie complète du répertoire |

---

## Restauration d'une configuration

### Via le script de restauration
```bash
# Lister les sauvegardes disponibles
/usr/local/bin/cisco-tftp-restore.sh

# Restaurer la dernière sauvegarde d'un équipement
/usr/local/bin/cisco-tftp-restore.sh SW2-IRIS

# Restaurer une sauvegarde d'une date spécifique
/usr/local/bin/cisco-tftp-restore.sh SW2-IRIS 20250101
```

### Commande sur l'équipement Cisco (après avoir obtenu le chemin)
```
copy tftp://192.168.50.20/cisco-backups/SW2-IRIS/SW2-IRIS_20250101_020000.cfg running-config
```

---

## Vérification des sauvegardes

```bash
# Logs de sauvegarde
tail -50 /var/log/tftp-backup.log

# Vérifier les fichiers présents
ls -lh /srv/tftp/cisco-backups/SW2-IRIS/
ls -lh /srv/tftp/cisco-backups/AP2-IRIS/

# Test manuel immédiat
/usr/local/bin/cisco-tftp-backup.sh

# Vérifier le statut tftpd-hpa
systemctl status tftpd-hpa
```

---

## Alertes

En cas d'échec de sauvegarde, un message est envoyé dans syslog (`local0.warning`) :
```
logger: ALERTE: N équipement(s) non sauvegardé(s)
```

Vérifier avec : `grep cisco-backup /var/log/syslog`

---

## Notes de sécurité

- La communauté SNMP `iris-ro` est en lecture seule et restreinte au VLAN 50 (ACL 99)
- La communauté `iris-rw` est restreinte au VLAN 50 uniquement
- Le serveur TFTP écoute sur toutes les interfaces — filtrer via iptables si nécessaire :
  ```bash
  iptables -A INPUT -p udp --dport 69 ! -s 192.168.50.0/24 -j DROP
  iptables -A INPUT -p udp --dport 69 ! -s 192.168.0.0/16 -j DROP
  ```
