# RP-01 — Infrastructure Sécurisée Windows Server 2022 — IRIS Nice

**Épreuve E5 — BTS SIO option SISR** | Mediaschool Nice  
Auteur : **Nedjmeddine Belloum** — Chef de projet

---

## 🎯 Contexte

Dans le cadre du BTS SIO SISR, réponse à un appel d'offre réel de l'école IRIS Nice pour concevoir et déployer une infrastructure réseau sécurisée. L'école ne disposait d'aucune segmentation réseau, d'aucune authentification individuelle et d'aucun environnement de virtualisation dédié à la formation.

---

## 🏗️ Architecture

### Composants

| Composant | Technologie | IP |
|---|---|---|
| **DC-IRIS-01** | Windows Server 2022 — AD DS + DNS + DHCP + NPS/RADIUS | 192.168.50.10 |
| **SRV-LINUX-IRIS** | Ubuntu 22.04 + Docker (10 services) | 192.168.50.20 |
| **SW2-IRIS** | Cisco Catalyst 2960-S — 802.1X sur chaque port | 192.168.50.2 |
| **RT2-IRIS** | Cisco ISR 1941W — inter-VLAN routing + NAT | 192.168.50.1 |

### Segmentation réseau — 6 VLANs

| VLAN | Nom | Réseau | Usage |
|---|---|---|---|
| 10 | Étudiants | 192.168.10.0/24 | Accès pédagogique |
| 20 | Profs | 192.168.20.0/24 | Corps enseignant |
| 30 | Administration | 192.168.30.0/24 | Personnel administratif |
| 40 | Guest | 192.168.40.0/24 | Invités — Internet uniquement |
| **50** | **Management IT** | **192.168.50.0/24** | Infrastructure réseau |
| **99** | **PRE_AUTH** | **192.168.99.0/24** | Quarantaine 802.1X |

### Flux d'authentification 802.1X

```
PC → Port 802.1X (SW2-IRIS) → NPS/RADIUS (DC-IRIS-01) → AD DS → Attribution VLAN
 1. PC se connecte au port switch
 2. Switch envoie une requête RADIUS (EAP) à NPS
 3. NPS vérifie les credentials dans l'Active Directory
 4. NPS retourne l'ID VLAN via Tunnel Attributes (RFC 3580)
 5. Switch configure automatiquement le port sur le bon VLAN
```

---

## 🚀 Déploiement automatisé (Vagrant + PowerShell)

### Pré-requis

- VirtualBox 7.x
- Vagrant 2.4+
- Box `gusztavvargadr/windows-server-2022-standard`
- Box `ubuntu/jammy64`

### Lancement

```powershell
vagrant up
# Les provisioners PowerShell s'exécutent dans l'ordre automatiquement
# Un redémarrage est requis entre le script 01 (install rôles) et 02 (promotion DC)
```

### Scripts de provisioning

| # | Script | Rôle | Statut |
|---|--------|------|--------|
| 01 | `01_install_roles.ps1` | Installation AD DS, DNS, DHCP, NPAS, RSAT | ✅ |
| 02 | `02_configure_ad.ps1` | Promotion DC, forêt mediaschool.local, 26 users AD | ✅ |
| 03 | `03_configure_dhcp.ps1` | 6 scopes DHCP par VLAN, exclusions, options | ✅ |
| 04 | `04_configure_nps.ps1` | Enregistrement NPS, 3 clients RADIUS, 6 politiques réseau | ✅ |
| 05 | `05_configure_gpo.ps1` | 4 GPOs, Fine-Grained Password Policies | ✅ |
| 06 | `linux_docker_services.sh` | Docker Compose — 10 services sur SRV-LINUX-IRIS | ✅ |

---

## 🐳 Services Docker (SRV-LINUX-IRIS)

| Service | Port | Rôle |
|---------|------|------|
| GLPI | :8080 | Helpdesk / inventaire parc |
| Nextcloud | :8443 | Stockage pédagogique partagé |
| Grafana | :3000 | Tableau de bord monitoring |
| Prometheus | :9090 | Collecte des métriques |
| Node Exporter | :9100 | Métriques système Linux |
| cAdvisor | :8081 | Métriques conteneurs Docker |
| MariaDB | :3306 | Base de données GLPI + Nextcloud |
| Redis | :6379 | Cache sessions Nextcloud |
| ClamAV | — | Antivirus temps réel |
| WireGuard | :51820/UDP | VPN administration distante |

---

## ✅ Résultats de déploiement (lab Vagrant)

| Test | Résultat |
|------|----------|
| Forêt AD `mediaschool.local` | ✅ Opérationnelle |
| 26 utilisateurs dans 5 groupes AD | ✅ Créés |
| 6 scopes DHCP actifs | ✅ Fonctionnels |
| NPS — 3 clients RADIUS + 6 politiques | ✅ Configurés |
| Docker — 9/10 conteneurs Up | ✅ (ClamAV nécessite ≥ 4 GB RAM) |
| Connectivité DC ↔ SRV-LINUX | ✅ < 2ms, 0% perte |
| Services GLPI, Nextcloud, Grafana | ✅ HTTP 200/302 |

---

## 📁 Structure du projet

```
.
├── Vagrantfile                         # VMs dc-iris + srv-linux
├── docker-compose.yml                  # 10 services Docker
├── .env                                # Variables d'environnement
├── monitoring/
│   └── prometheus.yml
├── scripts/
│   ├── 01_install_roles.ps1
│   ├── 02_configure_ad.ps1
│   ├── 03_configure_dhcp.ps1
│   ├── 04_configure_nps.ps1
│   ├── 05_configure_gpo.ps1
│   └── linux_docker_services.sh
├── cisco/
│   ├── SW2-IRIS_config.txt
│   └── RT2-IRIS_config.txt
└── Documentation/
    ├── 01_Plan_Tests_RP01.md
    ├── 02_Procedure_Utilisation_RP01.md
    ├── 03_Documentation_Technique_RP01.md
    ├── 04_Reponse_AO_RP01.md
    ├── 05_Annexe_Technique_RP01.md
    └── 06_Credentials_Access_RP01.md
```

---

## 🔗 Compétences BTS SIO mobilisées

| Compétence | Description |
|---|---|
| **B1.1** | Gérer le patrimoine informatique — AD, GPO, DHCP |
| **B1.2** | Répondre aux incidents — NPS, pare-feu, VLAN quarantaine |
| **B1.4** | Travailler en mode projet — appel d'offre, automatisation Vagrant |
| **B1.5** | Mettre à disposition un service informatique — Docker, provisioning |

---

## 👤 Auteur

**Nedjmeddine Belloum** — BTS SIO option SISR — Chef de projet  
Centre de formation : Mediaschool Nice (IRIS)  
Période : Février — Mars 2026  
Portfolio : [https://delcoco95.github.io/portfolio-nedj/](https://delcoco95.github.io/portfolio-nedj/)
