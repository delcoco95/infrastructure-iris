# Réponse Technique à l'Appel d'Offres
## RP01 — Modernisation Infrastructure Réseau IRIS Nice
### Référence : IRIS-NICE-2026-RP01

---

**Prestataire :** Nedjmeddine Belloum — BTS SIO SISR  
**Établissement :** MEDIASCHOOL Nice  
**Date de remise :** Avril 2026  
**Responsable technique client :** Yan Bourquard

---

## 1. Compréhension du besoin

L'école IRIS Nice souhaitait moderniser son infrastructure réseau en remplaçant une solution à plat (sans segmentation ni authentification) par une architecture sécurisée, segmentée et supervisée, répondant aux enjeux suivants :

| Besoin | Solution retenue |
|--------|-----------------|
| Segmentation réseau par profil utilisateur | 6 VLANs (Étudiants, Profs, Admin, Invités, Management, Quarantaine) |
| Authentification individuelle et traçabilité | 802.1X WPA2-Enterprise + PEAP/MSCHAPv2 adossé à Active Directory |
| Administration centralisée des identités | AD DS Windows Server 2022 + GPO |
| Services applicatifs (parc, stockage, supervision) | Stack Docker : GLPI, Nextcloud, Grafana, Prometheus |
| Accès distant sécurisé pour les techniciens | VPN WireGuard |
| Conformité et isolation des équipements inconnus | VLAN 99 PRE_AUTH (quarantaine 802.1X) |

---

## 2. Architecture déployée

### 2.1 Vue d'ensemble

```
INTERNET
    │
    ├─ RT2-IRIS (Cisco ISR 1941W — 192.168.50.1)
    │     Routage inter-VLAN, NAT, ACL étendues, SSH v2
    │
    └─ SW2-IRIS (Cisco Catalyst 2960-S — 192.168.50.2)
          802.1X sur ports d'accès, trunk vers RT2-IRIS et AP2-IRIS
          │
          ├─ DC-IRIS-01 (Windows Server 2022 — 192.168.50.10)
          │     AD DS, DNS, DHCP, NPS/RADIUS, ADCS (PKI interne)
          │
          ├─ SRV-LINUX-IRIS (Ubuntu 22.04 — 192.168.50.20)
          │     Docker : GLPI, Nextcloud, Grafana, Prometheus, WireGuard...
          │
          └─ AP2-IRIS (Cisco C9105AXI-E EWC — 192.168.50.5)
                4 SSIDs WPA2-Enterprise 802.1X
```

### 2.2 Segmentation réseau

| VLAN | Réseau | Profil | Accès |
|------|--------|--------|-------|
| 10 | 192.168.10.0/24 | Étudiants (SISR + SLAM) | Internet uniquement, isolé des autres VLANs |
| 20 | 192.168.20.0/24 | Professeurs | Internet + accès limité |
| 30 | 192.168.30.0/24 | Administration | Internet + accès interne |
| 40 | 192.168.40.0/24 | Invités / Visiteurs | Internet uniquement, isolation totale |
| 50 | 192.168.50.0/24 | Management IT | Accès complet (admins IT uniquement) |
| 99 | 192.168.99.0/24 | PRE_AUTH | Quarantaine — équipements non authentifiés |

---

## 3. Réalisations techniques

### 3.1 Équipements Cisco (matériel physique)

#### RT2-IRIS — Cisco ISR 1941W
- Routage inter-VLAN en Router-on-a-Stick (6 sous-interfaces 802.1Q)
- NAT overload vers Internet
- ACL étendues : isolation inter-VLAN, filtrage invités, protection management
- SSH v2 uniquement (telnet désactivé), syslog vers DC-IRIS-01

#### SW2-IRIS — Cisco Catalyst 2960-S
- 6 VLANs configurés avec SVIs et `ip helper-address` vers DHCP
- Authentification 802.1X sur ports d'accès (dot1x port-control auto)
- Guest VLAN 40 pour les équipements sans supplicant 802.1X
- VLAN 99 PRE_AUTH comme Auth-Fail VLAN
- Trunk vers RT2-IRIS (Gi0/1) et AP2-IRIS (Gi1/0/21)
- Port-security sur ports critiques

#### AP2-IRIS — Cisco C9105AXI-E (EWC IOS-XE 17.9.8.5)
- **Architecture FlexConnect** (données commutées localement sur le switch)
- **4 SSIDs WPA2-Enterprise 802.1X** avec VLAN statique par policy (Option A) :

| SSID | WLAN ID | Policy Profile | VLAN assigné |
|------|---------|---------------|-------------|
| IRIS-WIFI | 1 | POLICY-ETUDIANTS | 10 |
| IRIS-PROFS | 2 | POLICY-PROFS | 20 |
| IRIS-ADMIN | 3 | POLICY-ADMIN | 30 |
| IRIS-GUEST | 4 | POLICY-INVITES | 40 |

> **Note technique :** L'attribution VLAN dynamique via RADIUS (aaa-override + Tunnel-Pvt-Group-ID) a été testée et abandonnée — incompatibilité confirmée entre EWC 17.9.8.5 et FlexConnect local switching (VLAN failure systématique). Solution retenue : VLAN statique par policy profile (Option A), chaque SSID dédié à un rôle.

### 3.2 DC-IRIS-01 — Windows Server 2022

**Active Directory :**
- Forêt `mediaschool.local`, domaine unique
- Structure OU : `Utilisateurs > Étudiants > BTS_SIO_2annee > SISR/SLAM`, `Profs`, `Administration`, `Invités`, `CompteService`
- 25+ comptes utilisateurs de test
- Groupes de sécurité : `GRP_Etudiants_SISR`, `GRP_Etudiants_SLAM`, `GRP_Profs`, `GRP_Administration`, `GRP_Invites`, `GRP_IT_Admin`
- Fine-Grained Password Policies différenciées par profil
- GPO de sécurité : verrouillage session 10 min, SMB Signing, pare-feu Windows

**NPS/RADIUS :**
- 3 clients RADIUS : AP2-IRIS (192.168.50.5), SW2-IRIS (192.168.50.2), RT2-IRIS (192.168.50.1)
- 1 Connection Request Policy : `CRP_EAP_8021X`
- 4 Network Policies par groupe AD :

| Politique | Groupe AD | Méthode | Résultat |
|-----------|-----------|---------|----------|
| NP_Etudiants | GRP_Etudiants_SISR + GRP_Etudiants_SLAM | PEAP/MSCHAPv2 | GRANTED |
| NP_Profs | GRP_Profs | PEAP/MSCHAPv2 | GRANTED |
| NP_Admin | GRP_Administration | PEAP/MSCHAPv2 | GRANTED |
| NP_Guest | GRP_Invites | PEAP/MSCHAPv2 | GRANTED |

**DHCP :**
- 6 scopes actifs (VLAN 10, 20, 30, 40, 50, 99)
- Relais DHCP via `ip helper-address` sur SVIs du switch

**ADCS (PKI interne) :**
- Autorité de certification racine d'entreprise déployée
- Certificat serveur NPS émis — authentification PEAP sans avertissement de certificat (si AC déployée via GPO)

**Provisioning automatisé :**
- 6 scripts PowerShell séquentiels (~700 lignes) : `01_install_roles` → `02_configure_ad` → `03_configure_dhcp` → `04_configure_nps` → `05_configure_users` → `06_configure_gpo`

### 3.3 SRV-LINUX-IRIS — Ubuntu 22.04 + Docker

8 services déployés via `docker-compose.yml` :

| Service | Rôle | Port | URL |
|---------|------|------|-----|
| GLPI | Gestion de parc et helpdesk | 8082 | http://192.168.50.20:8082 |
| Nextcloud | Stockage collaboratif | 8081 | http://192.168.50.20:8081 |
| Grafana | Tableaux de bord supervision | 3000 | http://192.168.50.20:3000 |
| Prometheus | Collecte métriques (scrape 15s) | 9090 | http://192.168.50.20:9090 |
| Node Exporter | Métriques OS Linux | 9100 | http://192.168.50.20:9100 |
| CAdvisor | Métriques conteneurs Docker | 8083 | http://192.168.50.20:8083 |
| WireGuard (wg-easy) | VPN administration distante | 51820/UDP | http://192.168.50.20:51821 |
| ClamAV | Antivirus daemon | 3310 | tcp://192.168.50.20:3310 |

---

## 4. Tests et validation

### Résultats 802.1X WiFi (tests sur AP2-IRIS)

| Test | Compte | SSID | VLAN attendu | Résultat |
|------|--------|------|-------------|---------|
| T-W01 | nedj.belloum (GRP_Etudiants_SISR) | IRIS-WIFI | VLAN 10 (192.168.10.x) | ✅ PASS |
| T-W02 | yan.bourquard (GRP_Profs) | IRIS-PROFS | VLAN 20 (192.168.20.x) | ✅ PASS |
| T-W03 | Compte inconnu | IRIS-WIFI | Refus NPS | ✅ PASS |
| T-W04 | Mauvais mot de passe | IRIS-PROFS | Refus NPS | ✅ PASS |

### Infrastructure

| Composant | État |
|-----------|------|
| AD DS + DNS | ✅ Opérationnel |
| DHCP 6 scopes | ✅ Distribués |
| NPS 4 politiques | ✅ Actives |
| 802.1X câblé (SW2-IRIS) | ✅ Fonctionnel |
| 802.1X WiFi (AP2-IRIS) | ✅ 4 SSIDs opérationnels |
| GLPI | ✅ Accessible |
| Nextcloud | ✅ Accessible |
| Grafana + Prometheus | ✅ Dashboards actifs |
| WireGuard VPN | ✅ Déployé |

---

## 5. Livrables remis

| Livrable | Localisation |
|----------|-------------|
| Infrastructure as Code (Vagrantfile) | Racine du projet |
| Scripts PowerShell (6) | `scripts/` |
| docker-compose.yml | Racine du projet |
| Configs Cisco (RT2-IRIS, SW2-IRIS, AP2-IRIS) | `cisco/backups/` |
| Documentation technique (15 fichiers Markdown) | `Documentation/` |
| Schéma réseau complet | `Documentation/schema reseau/` |
| Plan de tests | `Documentation/01_Plan_Tests_RP01.md` |
| Procédure d'utilisation technicien | `Documentation/02_Procedure_Utilisation_RP01.md` |
| GitHub | https://github.com/delcoco95/infrastructure-iris |

---

## 6. Normes et référentiels appliqués

| Norme | Application |
|-------|-------------|
| IEEE 802.1X | Authentification port réseau câblé et WiFi |
| IEEE 802.11i (WPA2) | Sécurité WiFi WPA2-Enterprise |
| RFC 2865/2866 | RADIUS Authentication + Accounting |
| RFC 3580 | 802.1X RADIUS VLAN (câblé) |
| PEAP (RFC 5281) | Tunnel EAP sécurisé pour MSCHAPv2 |
| ANSSI — Recommandations WiFi | Désactivation WPS, WPA2 minimum |

---

*Nedjmeddine Belloum — BTS SIO SISR — MEDIASCHOOL / IRIS Nice — Session 2026*  
*Référence projet : IRIS-NICE-2026-RP01 | GitHub : https://github.com/delcoco95/infrastructure-iris*
