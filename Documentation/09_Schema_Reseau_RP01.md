# Schéma Réseau Complet — RP-01 IRIS Nice

---

## 1. Architecture générale (ASCII)

```
                         ┌─────────────────────────────────────────────┐
                         │              INTERNET                        │
                         └─────────────────────────────────────────────┘
                                              │
                                              │ WAN
                                    ┌─────────┴──────────┐
                                    │    RT2-IRIS         │
                                    │  Cisco ISR 1941W    │
                                    │  192.168.50.1/24    │
                                    │  NAT + Router-on-   │
                                    │  a-Stick (802.1Q)   │
                                    └─────────┬──────────┘
                                              │ Trunk (802.1Q)
                                              │ VLANs 10,20,30,40,50,99
                                    ┌─────────┴──────────┐
                                    │    SW2-IRIS         │
                                    │ Cisco Catalyst      │
                                    │    2960-S           │
                                    │  192.168.50.2/24    │
                                    │  802.1X sur ports   │
                                    │  accès              │
                                    └────┬──────┬─────────┘
                                         │      │
                     ┌───────────────────┘      └────────────────────┐
                     │ VLAN 50 (Management)       VLAN 50 (Management) │
          ┌──────────┴──────────┐              ┌──────────┴──────────┐
          │    DC-IRIS-01        │              │   SRV-LINUX-IRIS    │
          │  Windows Server 2022 │              │   Ubuntu 22.04 LTS  │
          │  192.168.50.10/24    │              │  192.168.50.20/24   │
          │                      │◄────LDAP────►│                     │
          │  ┌────────────────┐  │              │  ┌───────────────┐  │
          │  │  AD DS         │  │              │  │ Docker Engine │  │
          │  │  DNS           │  │              │  │               │  │
          │  │  DHCP          │  │              │  │ ┌───────────┐ │  │
          │  │  NPS/RADIUS    │  │              │  │ │   GLPI    │ │  │
          │  └────────────────┘  │              │  │ │  :8082    │ │  │
          └──────────────────────┘              │  │ ├───────────┤ │  │
                                                │  │ │Nextcloud  │ │  │
                                                │  │ │  :8081    │ │  │
                                                │  │ ├───────────┤ │  │
                                                │  │ │  Grafana  │ │  │
                                                │  │ │  :3000    │ │  │
                                                │  │ ├───────────┤ │  │
                                                │  │ │Prometheus │ │  │
                                                │  │ │  :9090    │ │  │
                                                │  │ ├───────────┤ │  │
                                                │  │ │WireGuard  │ │  │
                                                │  │ │:51820/UDP │ │  │
                                                │  │ └───────────┘ │  │
                                                │  └───────────────┘  │
                                                └─────────────────────┘

       ┌──────────────────────────────────────────────────────────────────┐
       │                      VLANs — Ports Switch                        │
       │                                                                   │
       │  Port 1     → Trunk (RT2-IRIS)                                   │
       │  Port 2     → Access VLAN 50 (DC-IRIS-01)                        │
       │  Port 3     → Access VLAN 50 (SRV-LINUX-IRIS)                    │
       │  Ports 4-23 → Access 802.1X → VLAN dynamique selon profil AD     │
       │  Ports 24   → Access VLAN 50 (Admin IT)                          │
       └──────────────────────────────────────────────────────────────────┘
```

---

## 2. Plan d'adressage IP complet

| Équipement | Interface | IP | Masque | VLAN | Rôle |
|---|---|---|---|---|---|
| RT2-IRIS | Fa0/0.10 | 192.168.10.1 | /24 | 10 | Passerelle Étudiants |
| RT2-IRIS | Fa0/0.20 | 192.168.20.1 | /24 | 20 | Passerelle Profs |
| RT2-IRIS | Fa0/0.30 | 192.168.30.1 | /24 | 30 | Passerelle Administration |
| RT2-IRIS | Fa0/0.40 | 192.168.40.1 | /24 | 40 | Passerelle Guest |
| RT2-IRIS | Fa0/0.50 | 192.168.50.1 | /24 | 50 | Passerelle Management IT |
| RT2-IRIS | Fa0/0.99 | 192.168.99.1 | /24 | 99 | Passerelle PRE_AUTH |
| SW2-IRIS | VLAN 50 SVI | 192.168.50.2 | /24 | 50 | Management switch |
| DC-IRIS-01 | NIC | 192.168.50.10 | /24 | 50 | AD DS / DNS / DHCP / NPS |
| SRV-LINUX-IRIS | NIC | 192.168.50.20 | /24 | 50 | Docker services |
| AP2-IRIS | NIC VLAN50 | 192.168.50.5 | /24 | 50 | WiFi 802.1X (EWC C9105AXI-E) |
| DHCP Étudiants | Pool | 192.168.10.31–254 | /24 | 10 | Attribution automatique |
| DHCP Profs | Pool | 192.168.20.31–254 | /24 | 20 | Attribution automatique |
| DHCP Admin | Pool | 192.168.30.31–254 | /24 | 30 | Attribution automatique |
| DHCP Guest | Pool | 192.168.40.31–254 | /24 | 40 | Attribution automatique |
| DHCP Mgmt | Pool | 192.168.50.31–254 | /24 | 50 | Attribution automatique |
| DHCP PRE_AUTH | Pool | 192.168.99.31–254 | /24 | 99 | Quarantaine 802.1X |

### Exclusions DHCP VLAN 50

| Plage exclue | Usage |
|---|---|
| 192.168.50.1 | RT2-IRIS (passerelle) |
| 192.168.50.2 | SW2-IRIS (management) |
| 192.168.50.10 | DC-IRIS-01 (fixe) |
| 192.168.50.20 | SRV-LINUX-IRIS (fixe) |
| 192.168.50.5 | AP2-IRIS (fixe) |
| 192.168.50.3–9 | Réservé équipements futurs |
| 192.168.50.11–19 | Réservé DCs secondaires |
| 192.168.50.21–30 | Réservé serveurs |

---

## 3. Flux d'authentification 802.1X (détail)

```
┌──────────┐    EAP-Request/Identity    ┌──────────────┐
│   PC      │◄──────────────────────────│  SW2-IRIS    │
│ Étudiant  │                           │ (Authenticator│
│           │    EAP-Response/Identity  │  802.1X)     │
│           │──────────────────────────►│              │
└──────────┘                           └──────┬───────┘
                                              │ RADIUS Access-Request
                                              │ (User=nedj.belloum, EAP payload)
                                    ┌─────────▼──────────┐
                                    │    DC-IRIS-01       │
                                    │  NPS / RADIUS       │
                                    │  192.168.50.10:1812 │
                                    └─────────┬──────────┘
                                              │ Vérifie AD
                                    ┌─────────▼──────────┐
                                    │    Active Directory │
                                    │  mediaschool.local  │
                                    │  OU=Etudiants?      │
                                    │  → Groupe GRP_Etudiants_SISR / GRP_Etudiants_SLAM  │
                                    └─────────┬──────────┘
                                              │
                          ┌───────────────────▼────────────────────┐
                          │        NPS — Politique réseau           │
                          │                                         │
                          │  NP_Etudiants                      │
                          │  Conditions : GRP_Etudiants_SISR + GRP_Etudiants_SLAM      │
                          │  Résultat : Access-Accept               │
                          │  Attributs RADIUS (RFC 3580) :          │
                          │    64 (Tunnel-Type)       = 13 (VLAN)   │
                          │    65 (Tunnel-Medium-Type)= 6  (802)    │
                          │    81 (Tunnel-PG-ID)      = "10"        │
                           │                                         │
                           │  ⚠ NOTE : Attributs RADIUS valables pour │
                           │  802.1X câblé (SW2-IRIS) UNIQUEMENT.    │
                           │  Pour WiFi (AP2-IRIS) : VLAN statique   │
                           │  dans la policy AP (Option A).          │
                          └───────────────────┬────────────────────┘
                                              │ RADIUS Access-Accept + VLAN 10
                                    ┌─────────▼──────────┐
                                    │    SW2-IRIS         │
                                    │  Port → VLAN 10     │
                                    │  DHCP → 192.168.10.x│
                                    └────────────────────┘

Résultats par groupe AD :
┌──────────────────────┬────────────────────┬──────────┬────────────────────┐
│ Groupe AD            │ Politique NPS       │ VLAN     │ Réseau             │
├──────────────────────┼────────────────────┼──────────┼────────────────────┤
│ SRV_Etudiants        │ NP_Etudiants   │ VLAN 10  │ 192.168.10.0/24   │
│ GRP_Profs               │ NP_Profs            │ VLAN 20  │ 192.168.20.0/24   │
│ GRP_Administration      │ NP_Admin            │ VLAN 30  │ 192.168.30.0/24   │
│ GRP_Invites             │ NP_Guest            │ VLAN 40  │ 192.168.40.0/24   │
│ GRP_IT_Admin            │ (NPS pass-through)  │ VLAN 50  │ 192.168.50.0/24   │
│ (aucun / inconnu)       │ (Guest VLAN 802.1X) │ VLAN 99  │ 192.168.99.0/24   │
└──────────────────────┴────────────────────┴──────────┴────────────────────┘
```

---

## 4. Architecture Docker (SRV-LINUX-IRIS)

```
                    SRV-LINUX-IRIS (192.168.50.20)
                    ┌────────────────────────────────────────────────┐
                    │              Docker Engine                      │
                    │                                                 │
                    │   ┌─────────────────────────────────────────┐  │
                    │   │         Réseau "frontend"               │  │
                    │   │  (accessible depuis VLAN 50)            │  │
                    │   │                                         │  │
                    │   │  ┌──────────┐  ┌──────────┐            │  │
                    │   │  │  GLPI    │  │Nextcloud │            │  │
                    │   │  │  :8082   │  │  :8081   │            │  │
                    │   │  └────┬─────┘  └────┬─────┘            │  │
                    │   │       │              │                  │  │
                    │   └───────┼──────────────┼──────────────────┘  │
                    │           │              │                      │
                    │   ┌───────┼──────────────┼──────────────────┐  │
                    │   │       │  Réseau "backend" (internal)    │  │
                    │   │  ┌────▼─────┐  ┌────▼─────┐            │  │
                    │   │  │ MariaDB  │  │ MariaDB  │            │  │
                    │   │  │  (GLPI)  │  │  (NC)    │            │  │
                    │   │  └──────────┘  └──────────┘            │  │
                    │   │                    ┌──────────┐         │  │
                    │   │                    │  Redis   │         │  │
                    │   │                    │  (cache) │         │  │
                    │   │                    └──────────┘         │  │
                    │   └────────────────────────────────────────┘  │
                    │                                                 │
                    │   ┌─────────────────────────────────────────┐  │
                    │   │         Réseau "monitoring"             │  │
                    │   │                                         │  │
                    │   │  ┌──────────┐  ┌──────────┐            │  │
                    │   │  │Prometheus│  │ Grafana  │            │  │
                    │   │  │  :9090   │  │  :3000   │            │  │
                    │   │  └────▲─────┘  └────▲─────┘            │  │
                    │   │       │              │                  │  │
                    │   │  ┌────┴─────┐  ┌────┴─────┐            │  │
                    │   │  │  Node    │  │ cAdvisor │            │  │
                    │   │  │ Exporter │  │  :8083   │            │  │
                    │   │  │  :9100   │  └──────────┘            │  │
                    │   │  └──────────┘                           │  │
                    │   └─────────────────────────────────────────┘  │
                    │                                                 │
                    │   ┌─────────────────────────────────────────┐  │
                    │   │              WireGuard VPN               │  │
                    │   │           :51820/UDP  :51821/TCP         │  │
                    │   └─────────────────────────────────────────┘  │
                    └────────────────────────────────────────────────┘

Volumes persistants → /opt/iris/{glpi,nextcloud,grafana,prometheus,...}
```

---

## 5. Tableau des ports exposés (host-only)

| Service | Conteneur | Port hôte | Port conteneur | Proto | URL accès |
|---|---|---|---|---|---|
| GLPI | glpi | **8082** | 80 | TCP | http://192.168.50.20:8082 |
| Nextcloud | nextcloud | **8081** | 80 | TCP | http://192.168.50.20:8081 |
| Grafana | grafana | 3000 | 3000 | TCP | http://192.168.50.20:3000 |
| Prometheus | prometheus | 9090 | 9090 | TCP | http://192.168.50.20:9090 |
| cAdvisor | cadvisor | 8083 | 8080 | TCP | http://192.168.50.20:8083 |
| Node Exporter | node-exporter | 9100 | 9100 | TCP | http://192.168.50.20:9100 |
| WireGuard UI | wireguard | 51821 | 51821 | TCP | http://192.168.50.20:51821 |
| WireGuard VPN | wireguard | 51820 | 51820 | UDP | — |
| RDP (DC) | — | 53389 | 3389 | TCP | mstsc /v:127.0.0.1:53389 |
| WinRM (DC) | — | 55985 | 5985 | TCP | PowerShell remoting |

---

## 6. Matrice de flux (ACLs RT2-IRIS)

| Source VLAN | Destination VLAN | Autorisé | Motif |
|---|---|---|---|
| 10 (Étudiants) | Internet | ✅ | NAT via RT2 |
| 10 (Étudiants) | 50 (Management) | ❌ | Isolation |
| 10 (Étudiants) | 20,30,40 | ❌ | Isolation inter-VLAN |
| 20 (Profs) | Internet | ✅ | NAT via RT2 |
| 20 (Profs) | 50 (Management) | ❌ | Isolation |
| 30 (Admin) | Internet | ✅ | NAT via RT2 |
| 30 (Admin) | 50 (Management) | ❌ | Isolation |
| 40 (Guest) | Internet uniquement | ✅ | NAT via RT2, filtré |
| 40 (Guest) | Tous VLANs internes | ❌ | Isolation totale |
| 50 (Management IT) | Tous VLANs | ✅ | Accès administration |
| 99 (PRE_AUTH) | Internet | ✅ | Portail captif possible |
| 99 (PRE_AUTH) | VLANs 10–50 | ❌ | Quarantaine stricte |

---

## 7. Environnement lab Vagrant (host-only)

```
PC Hôte (Windows 11)
192.168.50.0/24 (VirtualBox host-only adapter vboxnet)
    │
    ├── 192.168.50.10  →  DC-IRIS-01 (VirtualBox VM)
    │                      WinRM  : 127.0.0.1:55985
    │                      RDP    : 127.0.0.1:53389
    │
    └── 192.168.50.20  →  SRV-LINUX-IRIS (VirtualBox VM)
                           SSH    : 127.0.0.1:2222
                           GLPI   : 192.168.50.20:8082
                           NC     : 192.168.50.20:8081
                           Grafana: 192.168.50.20:3000
                           Prom   : 192.168.50.20:9090

Note : Les deux VMs communiquent entre elles via 192.168.50.x
       LDAP DC → SRV-LINUX : 192.168.50.10:389
       RADIUS SW → DC      : 192.168.50.10:1812 (UDP)
       RADIUS accounting   : 192.168.50.10:1813 (UDP)
```

---

## 8. Architecture WiFi — AP2-IRIS (4 SSIDs, Option A)

`
                    AP2-IRIS (Cisco C9105AXI-E EWC — 192.168.50.5)
                    ┌────────────────────────────────────────────────┐
                    │          EWC (Embedded Wireless Controller)     │
                    │          Firmware : IOS-XE 17.9.8.5            │
                    │                                                 │
                    │  ┌──────────────────────────────────────────┐  │
                    │  │  Policy Tag : PTAG-IRIS                  │  │
                    │  │  Flex Profile : default-flex-profile     │  │
                    │  └──────────────────────────────────────────┘  │
                    │                                                 │
                    │  WLAN 1  IRIS-WIFI    POLICY-ETUDIANTS VLAN 10 │
                    │  WLAN 2  IRIS-PROFS   POLICY-PROFS     VLAN 20 │
                    │  WLAN 3  IRIS-ADMIN   POLICY-ADMIN     VLAN 30 │
                    │  WLAN 4  IRIS-GUEST   POLICY-INVITES   VLAN 40 │
                    │                                                 │
                    │  Auth-list : DOT1X-IRIS → NPS-DC-IRIS-GROUP    │
                    │             → DC-IRIS-01:1812/1813              │
                    └────────────────────────────────────────────────┘

Flux d'authentification WiFi 802.1X (PEAP/MSCHAPv2) :

[Client WiFi]
    │ 1. Associe au SSID (ex: IRIS-WIFI)
    │
[AP2-IRIS EWC]
    │ 2. RADIUS Access-Request → NPS (192.168.50.10:1812)
    │
[DC-IRIS-01 — NPS]
    │ 3. Vérifie identifiants dans AD (PEAP/MSCHAPv2)
    │ 4. Consulte politiques réseau :
    │    - NP_Etudiants (ordre 1) → GRP_Etudiants_SISR + GRP_Etudiants_SLAM
    │    - NP_Profs     (ordre 2) → GRP_Profs
    │    - NP_Admin     (ordre 3) → GRP_Administration
    │    - NP_Guest     (ordre 4) → GRP_Invites
    │ 5. RADIUS Access-Accept (sans Tunnel attributes)
    │
[AP2-IRIS EWC]
    │ 6. Attribution VLAN STATIQUE défini dans la policy AP
    │    (PAS via RADIUS Tunnel-Pvt-Group-ID — incompatible EWC 17.9 + FlexConnect)
    │ 7. Client obtient IP DHCP du scope correspondant

⚠ LIMITATION EWC 17.9.8.5 : aaa-override + FlexConnect local switching provoque
  "VLAN failure". Solution : Option A — VLAN statique par policy AP dédiée par SSID.
`

### Politiques NPS (état FINAL)

| Politique | Ordre | Conditions | Résultat |
|-----------|-------|------------|---------|
| CRP_EAP_8021X | — | Toutes connexions 802.1X | Forward au NPS local |
| NP_Etudiants | 1 | GRP_Etudiants_SISR + GRP_Etudiants_SLAM, NAS-Port-Type=19 | GRANTED |
| NP_Profs | 2 | GRP_Profs | GRANTED |
| NP_Admin | 3 | GRP_Administration | GRANTED |
| NP_Guest | 4 | GRP_Invites | GRANTED |

> **Important :** L'attribution VLAN se fait côté AP (statique dans la policy).  
> NPS n'envoie PAS d'attributs Tunnel-Pvt-Group-ID pour le WiFi.
