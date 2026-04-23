# RP01 — Infrastructure Réseau Sécurisée IRIS Nice
## Présentation Portfolio — Nedjmeddine Belloum

---

## 🎯 En une phrase

> Déploiement d'une infrastructure réseau complète avec authentification 802.1X, segmentation VLAN sur matériel Cisco réel, Active Directory Windows Server 2022, et supervision Docker — pour un établissement de 300 utilisateurs.

---

## 📋 Contexte du projet

| | |
|---|---|
| **Client** | École IRIS Nice (300 utilisateurs) |
| **Prestataire** | NVTech |
| **Équipe** | 3 personnes — Nedjmeddine Belloum (chef de projet) |
| **Durée** | 5 mois |
| **Cadre** | Réponse à appel d'offre réel — BTS SIO SISR Épreuve E5 |
| **Référence** | IRIS-NICE-2026-RP01 |

**Problème résolu :** Le réseau IRIS Nice était un réseau plat sans aucune segmentation. Un étudiant lambda pouvait accéder aux ressources administratives et aux serveurs. Il n'existait ni contrôle d'accès, ni supervision, ni séparation des flux réseau.

---

## 🏗️ Ce qui a été construit

### Infrastructure physique Cisco
```
Internet
    │
    ▼
┌─────────────────────────────────────┐
│  RT2-IRIS (Cisco 1941W)             │  192.168.50.1
│  NAT + ACL inter-VLAN               │
└──────────────┬──────────────────────┘
               │ Trunk 802.1Q
               ▼
┌─────────────────────────────────────┐
│  SW2-IRIS (Cisco Catalyst 2960-S)   │  192.168.50.2
│  6 VLANs + 802.1X dot1x            │
└──┬──────────┬────────────┬──────────┘
   │          │            │
   ▼          ▼            ▼
VLAN 10   VLAN 20      AP-IRIS (Wi-Fi)
Étudiants Professeurs  802.1X WPA2-Enterprise
```

### Segmentation en 6 VLANs
| VLAN | Réseau | Utilisateurs |
|---|---|---|
| **10** — Étudiants | 192.168.10.0/24 | ~200 étudiants SISR/SLAM |
| **20** — Professeurs | 192.168.20.0/24 | Corps enseignant |
| **30** — Administration | 192.168.30.0/24 | Équipe administrative |
| **40** — Invités | 192.168.40.0/24 | Visiteurs, BYOD |
| **50** — Management IT | 192.168.50.0/24 | Équipements réseau, serveurs |
| **99** — PRE_AUTH | 192.168.99.0/24 | Quarantaine (non authentifiés) |

### Serveur Windows Server 2022 — DC-IRIS-01 (192.168.50.10)
Provisioning automatisé par **6 scripts PowerShell** (700+ lignes) :
- **Active Directory** : forêt `mediaschool.local`, 5 OUs, 20+ utilisateurs test
- **DNS** : résolution interne et externe
- **DHCP** : 6 scopes avec plages dédiées par VLAN
- **NPS/RADIUS** : 3 clients RADIUS + 6 politiques réseau 802.1X
- **GPO** : verrouillage de session, FGPP, firewall, SMB Signing
- **Automatisation** : import en masse utilisateurs, jointure domaine

### Serveur Linux — SRV-LINUX-IRIS (192.168.50.20)
**9 services Docker** déployés via docker-compose.yml :

| Service | URL | Usage |
|---|---|---|
| GLPI | :8082 | Gestion parc + tickets |
| Nextcloud | :8081 | Stockage pédagogique partagé |
| Grafana | :3000 | Dashboards supervision |
| Prometheus | :9090 | Collecte métriques |
| WireGuard (wg-easy) | :51821 | VPN administration |
| ClamAV | :3310 | Antivirus réseau |
| cAdvisor | :8083 | Monitoring conteneurs Docker |
| phpLDAPadmin | :6443 | Interface LDAP web |
| Portainer | :9443 | Gestion Docker GUI |

---

## 🔐 Authentification 802.1X — Le cœur du projet

### Principe
L'authentification 802.1X permet d'**assigner automatiquement** un utilisateur au bon VLAN en fonction de son identité Active Directory :

```
[PC Étudiant] ──EAP-MSCHAPv2──► [Switch SW2-IRIS] ──RADIUS──► [NPS DC-IRIS-01]
                                                                      │
                                                         Vérifie dans AD: "etudiant1" → groupe SISR
                                                                      │
                                              ◄── Access-Accept (VLAN-ID=10) ──┘
[PC Étudiant] reçoit IP 192.168.10.x, accès limité ✅
```

### Résultat
- Un **inconnu** sans compte AD → VLAN 99 (quarantaine, Internet seulement)
- Un **étudiant** → VLAN 10
- Un **professeur** → VLAN 20
- Un **admin** → VLAN 30

**Aucune manipulation manuelle** du switch n'est nécessaire — tout est dynamique.

---

## 📊 Supervision temps réel

**Stack Prometheus + Grafana** sur SRV-LINUX-IRIS :
- Métriques système : CPU, RAM, disque, réseau
- Métriques Docker : état des conteneurs, ressources
- Alertes automatiques configurées (Alertmanager)
- Dashboard accessible à l'équipe IT : http://192.168.50.20:3000

---

## ✅ Résultats et performances

| Indicateur | Résultat |
|---|---|
| VLANs opérationnels | 6/6 ✅ |
| Scopes DHCP actifs | 6/6 ✅ |
| Clients RADIUS configurés | 3/3 ✅ |
| Politiques NPS actives | 6/6 ✅ |
| Services Docker actifs | 9/9 ✅ |
| Latence DC ↔ SRV-LINUX | < 2 ms ✅ |
| Tests lab validés | 22/53 (31 nécessitent matériel physique) |

---

## 🛠️ Technologies maîtrisées

```
Windows Server 2022    Active Directory    NPS / RADIUS    DHCP / DNS
Cisco IOS (CLI)        802.1X dot1x       VLAN / Trunk    ACL / NAT
Docker / Compose       Vagrant / VBox     PowerShell      Bash
Prometheus / Grafana   WireGuard VPN      ClamAV          Linux Ubuntu 22.04
```

---

## 💡 Points techniques remarquables

**1. Scripts PowerShell entièrement automatisés**  
Toute l'infrastructure Windows (AD, DNS, DHCP, NPS, GPO, utilisateurs) se déploie en une seule séquence de 6 scripts. Zéro manipulation manuelle.

**2. Fine-Grained Password Policies différenciées**  
Les étudiants ont une politique de mot de passe différente des admins — impossible avec la politique de domaine standard. Nécessite la création d'une PSO (Password Settings Object).

**3. VLAN 99 comme filet de sécurité**  
Au lieu de bloquer totalement les non-authentifiés (ce qui peut causer des problèmes réseau), ils atterrissent en VLAN 99 avec accès Internet uniquement. Les ACL bloquent l'accès aux VLANs internes.

**4. Réseau host-only VirtualBox**  
Correction d'une configuration initiale `virtualbox__intnet` (réseau interne isolé, hôte ne peut pas contacter les VMs) vers `private_network` host-only (hôte + VMs se voient).

---

## 📁 Livrables

- **Code source** : https://github.com/delcoco95/infrastructure-iris
- **Documentation** : 10 fichiers Markdown (plan de tests, procédures, schémas réseau, benchmark)
- **Vagrantfile** : déploiement reproductible en `vagrant up`
- **Scripts PowerShell** : `scripts/` — 6 fichiers, ~700 lignes

---

## 🔗 Liens

- **GitHub :** https://github.com/delcoco95/infrastructure-iris
- **Portfolio :** https://delcoco95.github.io/portfolio-nedj/
- **Candidat :** Nedjmeddine Belloum — BTS SIO SISR — MEDIASCHOOL IRIS Nice — 2026
