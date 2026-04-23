# ANNEXE 7 — FICHE DE PRÉSENTATION DE LA SITUATION PROFESSIONNELLE
## BTS SIO — Épreuve E5 — Session 2026

---

| | |
|---|---|
| **Candidat** | Nedjmeddine Belloum |
| **Établissement** | MEDIASCHOOL / IRIS Nice |
| **Classe** | BTS SIO — option SISR |
| **Référence** | IRIS-NICE-2026-RP01 |
| **Date de réalisation** | Novembre 2025 – Avril 2026 |

---

## 1. IDENTIFICATION DE LA SITUATION

**Intitulé :**  
Déploiement d'une infrastructure réseau sécurisée avec authentification 802.1X / NPS-RADIUS sur Windows Server 2022 pour l'école IRIS Nice

**Contexte organisationnel :**  
L'école IRIS Nice (établissement supérieur, ~300 utilisateurs : étudiants, professeurs, administration, visiteurs) disposait d'un réseau plat sans segmentation ni contrôle d'accès. NVTech, prestataire informatique, a été mandaté en réponse à un appel d'offre pour concevoir et déployer une infrastructure sécurisée conforme aux standards professionnels.

**Durée de la situation :** 5 mois (projet long)  
**Taille de l'équipe :** 3 personnes — Nedjmeddine Belloum (chef de projet), 2 collaborateurs

---

## 2. DESCRIPTION DE LA SITUATION

### 2.1 Problématique initiale
Le réseau existant présentait plusieurs failles critiques :
- Réseau plat sans VLAN : un étudiant pouvait accéder aux ressources administratives
- Aucune authentification réseau : tout équipement branché obtenait un accès total
- Aucune supervision : pas d'alertes en cas de panne ou d'anomalie
- Infrastructure obsolète : serveur Linux avec FreeRADIUS mal documenté, non maintenable

### 2.2 Solution déployée

**Couche réseau (matériel Cisco physique) :**
- Routeur Cisco ISR 1941W (RT2-IRIS — 192.168.50.1) avec NAT et ACL inter-VLAN
- Switch Cisco Catalyst 2960-S (SW2-IRIS — 192.168.50.2) avec 6 VLANs configurés
- Point d'accès Wi-Fi Cisco C9105AXI-E (AP-IRIS — 192.168.50.24) — WPA2-Enterprise 802.1X

**Segmentation réseau — 6 VLANs :**

| VLAN | Nom | Réseau | Rôle |
|---|---|---|---|
| 10 | Étudiants | 192.168.10.0/24 | Accès limité (Internet + ressources pédagogiques) |
| 20 | Professeurs | 192.168.20.0/24 | Accès étendu (ressources internes) |
| 30 | Administration | 192.168.30.0/24 | Accès complet |
| 40 | Invités | 192.168.40.0/24 | Internet uniquement |
| 50 | Management IT | 192.168.50.0/24 | Serveurs, équipements actifs |
| 99 | PRE_AUTH | 192.168.99.0/24 | Quarantaine (non authentifiés) |

**Serveur DC-IRIS-01 — Windows Server 2022 (192.168.50.10) :**
- Active Directory Domain Services (domaine : mediaschool.local)
- DNS intégré à l'AD
- DHCP avec 6 scopes (un par VLAN)
- NPS/RADIUS — authentification 802.1X (assignation automatique des VLANs)
- GPO de sécurité : Fine-Grained Password Policies, verrouillage de session, pare-feu
- Provisioning entièrement automatisé par 6 scripts PowerShell

**Serveur SRV-LINUX-IRIS — Ubuntu 22.04 (192.168.50.20) :**
- 9 services Docker : GLPI, Nextcloud, Grafana, Prometheus, WireGuard, ClamAV, cAdvisor, phpLDAPadmin, Portainer
- Stack de monitoring : Prometheus + Grafana + cAdvisor + Node Exporter
- VPN WireGuard (wg-easy) pour administration distante sécurisée
- Antivirus ClamAV avec base de signatures actualisée

### 2.3 Mécanisme 802.1X (flux d'authentification)
```
Utilisateur            Switch SW2-IRIS          DC-IRIS-01 (NPS/RADIUS)
     │                       │                         │
     │ ── EAPOL Start ──────►│                         │
     │                       │ ── RADIUS Access-Req ──►│
     │                       │      (identifiants AD)  │
     │                       │ ◄── RADIUS Access-Acc ──│
     │                       │      (VLAN-ID = 10/20/30/40/99)
     │◄── Port autorisé ─────│                         │
     │    + VLAN assigné      │                         │
```

---

## 3. COMPÉTENCES BTS SIO MOBILISÉES

| Code | Compétence | Application concrète dans RP01 |
|---|---|---|
| **B1.1** | Recenser et identifier les ressources | Inventaire équipements Cisco, VMs, services Docker, plan d'adressage IP complet |
| **B1.2** | Exploiter les documentations | Documentation Cisco IOS, RFC 3580 (VLAN via RADIUS), PowerShell AD/NPS |
| **B1.3** | Mettre en place les niveaux d'habilitation | 6 groupes AD, 6 politiques NPS, FGPP différenciées, GPO par OU |
| **B2.1** | Intervenir sur les éléments du SI | Configuration Cisco CLI, scripts PowerShell, Docker Compose, Vagrant |
| **B2.2** | Garantir la disponibilité | Monitoring Prometheus/Grafana, alertes Alertmanager, DHCP HA |
| **B3.1** | Mettre en œuvre la sécurité | 802.1X WPA2-Enterprise, ACL inter-VLAN, VPN WireGuard, SMB Signing |
| **B3.2** | Assurer la supervision | Prometheus + Grafana + cAdvisor + Node Exporter — dashboards temps réel |

---

## 4. ENVIRONNEMENT TECHNIQUE

### Matériel physique (Cisco)
| Équipement | Modèle | IP | Rôle |
|---|---|---|---|
| Routeur | Cisco ISR 1941W | 192.168.50.1 | Routage inter-VLAN, NAT, ACL |
| Switch | Cisco Catalyst 2960-S | 192.168.50.2 | Commutation, 802.1X, trunk |
| AP Wi-Fi | Cisco C9105AXI-E | 192.168.50.24 | WPA2-Enterprise 802.1X |

### VMs (Lab Vagrant/VirtualBox)
| VM | OS | IP | RAM | Rôle |
|---|---|---|---|---|
| DC-IRIS-01 | Windows Server 2022 | 192.168.50.10 | 4 Go | AD DS + DNS + DHCP + NPS |
| SRV-LINUX-IRIS | Ubuntu 22.04 LTS | 192.168.50.20 | 2 Go | Docker (9 services) |

### Technologies et outils
- **Windows Server 2022** : AD DS, NPS, DHCP, DNS, GPO
- **PowerShell** : 6 scripts d'automatisation (700+ lignes)
- **Cisco IOS** : VLANs, dot1x, RADIUS, ACL, NAT
- **Docker + Docker Compose** : orchestration 9 services
- **Vagrant + VirtualBox** : provisioning automatisé
- **Prometheus + Grafana** : supervision et dashboards
- **WireGuard** : VPN administration

---

## 5. RÉSULTATS ET VALIDATION

### Tests réalisés en environnement lab
- ✅ 6 scopes DHCP actifs (un par VLAN)
- ✅ 3 clients RADIUS configurés (SW2-IRIS, RT2-IRIS, AP-IRIS)
- ✅ 6 politiques NPS avec assignation VLAN
- ✅ Latence DC ↔ SRV-LINUX < 2 ms
- ✅ 9 services Docker opérationnels
- ✅ Grafana : dashboards CPU, RAM, réseau, Docker temps réel
- ✅ VPN WireGuard : tunnel actif

### Indicateurs de sécurité
- VLAN 99 quarantaine : équipements non authentifiés isolés des VLANs internes
- FGPP : admins — 12 caractères min, blocage 3 tentatives ; étudiants — 8 caractères
- ACL : blocage trafic croisé entre VLANs non autorisés
- SMB Signing : activé sur tout le domaine

---

## 6. DIFFICULTÉS RENCONTRÉES ET SOLUTIONS

| Difficulté | Cause | Solution appliquée |
|---|---|---|
| DC inaccessible après promotion AD | WinRM désactivé lors de la promotion | Attente 30s, reconnexion via PowerShell Remoting |
| DHCP ne distribue pas d'IP | Service non autorisé dans l'AD | `Add-DhcpServerInDC` dans le script |
| NPS ne reconnaît pas les clients RADIUS | Nom du client = FQDN requis | Utilisation de l'IP directement dans `netsh nps add client` |
| Clavier QWERTY sur DC-IRIS-01 | Locale anglaise par défaut Vagrant | `Set-WinUserLanguageList fr-FR` via PSSession distante |
| VMs inaccessibles depuis l'hôte | `virtualbox__intnet` = réseau interne isolé | Suppression de `virtualbox__intnet` → adaptateur host-only |

---

## 7. LIENS

- **GitHub :** https://github.com/delcoco95/infrastructure-iris
- **Portfolio :** https://delcoco95.github.io/portfolio-nedj/
- **Référence BTS SIO :** IRIS-NICE-2026-RP01

---

*Nedjmeddine Belloum — BTS SIO SISR — MEDIASCHOOL / IRIS Nice — Session 2026*
