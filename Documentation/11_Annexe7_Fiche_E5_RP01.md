# ANNEXE 7-1-A — Fiche descriptive de réalisation professionnelle
## BTS Services informatiques aux organisations — SESSION 2026
## Épreuve E5 - Administration des systèmes et des réseaux (option SISR)

---

## RECTO — DESCRIPTION D'UNE RÉALISATION PROFESSIONNELLE

| | |
|---|---|
| **N° réalisation** | 1 |
| **Nom, prénom** | Belloum Nedjmeddine |
| **N° candidat** | *(à compléter)* |
| **Type d'épreuve** | Contrôle en cours de formation |
| **Date** | 23 / 03 / 2026 |

---

### Organisation support de la réalisation professionnelle

| | |
|---|---|
| **Intitulé de la réalisation professionnelle** | Conception, installation et sécurisation d'une infrastructure réseau Windows Server 2022 — École IRIS Nice |
| **Période de réalisation** | 23/03/2026 au 28/03/2026 |
| **Lieu** | Mediaschool – IRIS Nice |
| **Modalité** | En équipe (chef de projet : Nedjmeddine Belloum — 3 personnes) |

---

### Compétences travaillées

- [x] Concevoir une solution d'infrastructure réseau
- [x] Installer, tester et déployer une solution d'infrastructure réseau
- [x] Exploiter, dépanner et superviser une solution d'infrastructure réseau

---

### Conditions de réalisation

**Ressources :**
- Appel d'offre IRIS-NICE-2026-RP01 fourni par Yan Bourquard (Responsable Technique)
- Matériel Cisco disponible sur site : ISR 1941W, Catalyst 2960-S (SW2-IRIS), AP C9105AXI-E
- Environnement de test : 2 VMs Vagrant/VirtualBox (Windows Server 2022 + Ubuntu 22.04)
- Accès Internet pour téléchargement des outils et mises à jour

**Résultats attendus :**
- Infrastructure réseau segmentée en 6 VLANs opérationnelle sur matériel Cisco réel
- Authentification 802.1X individuelle — NPS/RADIUS + Active Directory Windows Server 2022
- Attribution dynamique des VLANs selon le profil AD (Étudiants/Profs/Admin/Invités/Quarantaine)
- 9 services Docker opérationnels : GLPI, Nextcloud, Grafana, Prometheus, WireGuard, ClamAV…
- GPO de sécurité, Fine-Grained Password Policies et supervision Prometheus/Grafana actifs

---

### Description des ressources documentaires, matérielles et logicielles utilisées

**Ressources documentaires :**
- Documentation Cisco IOS — Catalyst 2960-S, ISR 1941W
- Documentation Microsoft NPS/RADIUS et Active Directory Domain Services
- RFC 3580 — IEEE 802.1X RADIUS Usage Guidelines (VLAN via Tunnel Attributes)
- Recommandations ANSSI — sécurisation routeurs et commutateurs
- Appel d'offre IRIS-NICE-2026-RP01

**Matérielles et logicielles utilisées :**
- Cisco ISR 1941W — Routeur principal (routage inter-VLAN, NAT, ACL)
- Cisco Catalyst 2960-S (SW2-IRIS) — Switch 48 ports (802.1X, 6 VLANs, trunk)
- Cisco C9105AXI-E — Point d'accès Wi-Fi (WPA2-Enterprise 802.1X)
- DC-IRIS-01 : Windows Server 2022 Standard — AD DS, DNS, DHCP, NPS (RADIUS) — 4 Go RAM
- SRV-LINUX-IRIS : Ubuntu 22.04 LTS — Docker Compose, 9 services — 2 Go RAM
- Vagrant + VirtualBox — provisioning automatisé des VMs
- PowerShell — 6 scripts d'automatisation (~700 lignes)

---

### Modalités d'accès aux productions et à leur documentation

- **GitHub :** https://github.com/delcoco95/infrastructure-iris
- **Portfolio :** https://delcoco95.github.io/portfolio-nedj/
- **Maquette démontrable :** `vagrant up` → services démarrés automatiquement via provisioning

---

## VERSO — Descriptif de la réalisation professionnelle

---

**Objectif :**

Réponse à l'appel d'offre IRIS-NICE-2026-RP01 pour la conception et le déploiement d'une infrastructure réseau sécurisée complète pour l'école IRIS Nice. L'infrastructure existante était un réseau plat sans segmentation, authentification ni supervision. En tant que chef de projet, j'ai coordonné une équipe de 3 personnes sur 5 semaines.

---

**Ce qui a été réalisé :**

**1. Configuration Cisco (matériel physique) :**
- Routeur ISR 1941W (RT2-IRIS — 192.168.50.1) : routage inter-VLAN (Router-on-a-Stick), 6 sous-interfaces, ACL étendues inter-VLAN, NAT vers Internet, SSH v2, syslog
- Switch Catalyst 2960-S (SW2-IRIS — 192.168.50.2) : 6 VLANs, trunk Gi0/1, dot1x sur tous les ports, Guest VLAN 40, VLAN 99 quarantaine, port-security
- AP Cisco C9105AXI-E (AP-IRIS — 192.168.50.24) : SSID IRIS-SECURE, WPA2-Enterprise adossé à NPS/RADIUS

**2. Serveur DC-IRIS-01 — Windows Server 2022 (192.168.50.10) :**
- Active Directory Domain Services : forêt `mediaschool.local`, 5 OUs (SISR, SLAM, Professeurs, Admin, Invités), 20+ utilisateurs test
- DNS intégré à l'AD — résolution interne et externe
- DHCP : 6 scopes avec plages dédiées par VLAN (VLAN 10 → 20 → 30 → 40 → 50 → 99)
- NPS (Network Policy Server / RADIUS) : 3 clients RADIUS (SW2-IRIS, RT2-IRIS, AP-IRIS), 6 politiques réseau avec assignation VLAN automatique via Tunnel Attributes RFC 3580
- GPO : verrouillage de session (10 min), SMB Signing, pare-feu Windows actif, Fine-Grained Password Policies (FGPP) différenciées par groupe
- Provisioning automatisé par 6 scripts PowerShell séquentiels (~700 lignes) : install_roles → configure_ad → configure_dhcp → configure_nps → configure_users → configure_gpo

**3. Serveur SRV-LINUX-IRIS — Ubuntu 22.04 (192.168.50.20) :**
- 9 services Docker via docker-compose.yml : GLPI (parc + tickets), Nextcloud (stockage pédagogique), Grafana, Prometheus, cAdvisor, Node Exporter, WireGuard (wg-easy), ClamAV, Portainer
- Stack monitoring : Prometheus scrape toutes les 15s, Grafana dashboards CPU/RAM/réseau/Docker
- VPN WireGuard : tunnel administration distante via VLAN 50

**4. Tests et validation :**
- 6 scopes DHCP actifs et distribués
- 3 clients RADIUS configurés, 6 politiques NPS actives
- 9 services Docker opérationnels (tous les healthchecks verts)
- Communication DC-IRIS ↔ SRV-LINUX < 2 ms de latence
- 22 tests validés en environnement lab (31 nécessitent le matériel Cisco physique)

**5. Documentation livrée :**
- 10 documents Markdown : plan de tests (T-01 à T-53), procédures, doc technique, schéma réseau complet, benchmark 9 technologies, credentials lab, préparation oral E5/E6

---

**Compétences mobilisées :**
- Configuration Cisco IOS : VLANs, dot1x 802.1X, ACL étendues, DHCP, SSH, trunk
- Administration Windows Server 2022 : AD DS, NPS/RADIUS, DHCP, DNS, GPO, FGPP
- Scripting PowerShell : automatisation complète du provisioning (6 scripts)
- Administration Linux Ubuntu 22.04 : Docker Compose, UFW, systemd, réseau
- Supervision : Prometheus, Grafana, cAdvisor, Node Exporter
- Sécurité réseau : 802.1X WPA2-Enterprise, ACL, port-security, VPN WireGuard
- Gestion de projet : chef de projet en équipe de 3, RACI, documentation technique

---

*Nedjmeddine Belloum — BTS SIO SISR — MEDIASCHOOL / IRIS Nice — Session 2026*
