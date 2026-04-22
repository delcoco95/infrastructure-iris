# 🔐 Référentiel Accès & Identifiants — RP-01 IRIS Nice
## Document confidentiel — Usage lab/test uniquement

**Référence :** IRIS-NICE-2024-RP01  
**Version :** 1.0  
**Date :** Avril 2026  
**Auteur :** Nedjmeddine Belloum — BTS SIO SISR  
**⚠️ CONFIDENTIEL — Ne pas partager en dehors de l'environnement de test**

---

## 1. Accès aux VMs (Vagrant Lab)

### 1.1 Commandes Vagrant

```powershell
# Depuis : C:\Users\nedjb\Documents\PROJET IT\- RP01 - Infra Securite - Nedj\

vagrant up              # Démarrer les 2 VMs
vagrant status          # Vérifier l'état
vagrant halt            # Arrêter les VMs
vagrant ssh srv-linux   # SSH dans la VM Linux
vagrant rdp dc-iris     # Bureau distant DC (si RDP configuré)
```

### 1.2 Accès WinRM (Windows Server DC-IRIS-01)

| Paramètre | Valeur |
|-----------|--------|
| Hôte | 127.0.0.1 |
| Port WinRM | 55985 |
| Port RDP | 53389 |
| Utilisateur | `vagrant` |
| Mot de passe | `vagrant` |
| Transport | Negotiate |

```powershell
# Session PowerShell distante
$cred = New-Object PSCredential("vagrant", (ConvertTo-SecureString "vagrant" -AsPlainText -Force))
$s = New-PSSession -ComputerName 127.0.0.1 -Port 55985 -Credential $cred -Authentication Negotiate
Invoke-Command -Session $s -ScriptBlock { ... }
```

### 1.3 Accès SSH (Ubuntu srv-linux)

```bash
vagrant ssh srv-linux
# OU directement :
ssh -p 2222 vagrant@127.0.0.1  # (port NAT Vagrant)
# Mot de passe : vagrant
```

---

## 2. Comptes Windows Server / Active Directory

### 2.1 Comptes système

| Compte | Rôle | Mot de passe | Notes |
|--------|------|-------------|-------|
| `vagrant` | Admin local Vagrant | `vagrant` | Membre Enterprise Admins (ajouté manuellement) |
| `Administrator` | Admin domaine builtin | `NVTech_Admin2026!` | MEDIASCHOOL\Administrator |
| `MEDIASCHOOL\nedj.belloum.admin` | Admin IT Domain Admins | `NVTech_Admin2026!` | Compte admin principal |
| `MEDIASCHOOL\svc_nps` | Compte service NPS | `SvcNPS_IRIS_2026!` | Membre RAS and IAS Servers |

### 2.2 Comptes utilisateurs AD par groupe

| SAM Account | Nom | Groupe | Mot de passe | VLAN |
|------------|-----|--------|-------------|------|
| `nedj.belloum` | Nedj Belloum | GRP_Etudiants_SISR | `PasswordSISR2_2026!` | 10 |
| `edib.saoud` | Edib Saoud | GRP_Etudiants_SISR | `PasswordSISR2_2026!` | 10 |
| `julien.marcucci` | Julien Marcucci | GRP_Etudiants_SISR | `PasswordSISR2_2026!` | 10 |
| `louka.lavenir` | Louka Lavenir | GRP_Etudiants_SISR | `PasswordSISR2_2026!` | 10 |
| `omar.talibi` | Omar Talibi | GRP_Etudiants_SISR | `PasswordSISR2_2026!` | 10 |
| `remi.bears` | Remi Bears | GRP_Etudiants_SISR | `PasswordSISR2_2026!` | 10 |
| `said.ahmedmoussa` | Said Ahmed Moussa | GRP_Etudiants_SISR | `PasswordSISR2_2026!` | 10 |
| `vincent.andreo` | Vincent Andreo | GRP_Etudiants_SISR | `PasswordSISR2_2026!` | 10 |
| `hendrik.thouvenin` | Hendrik Thouvenin | GRP_Etudiants_SISR | `PasswordSISR2_2026!` | 10 |
| `yanis.adidi` | Yanis Adidi | GRP_Etudiants_SLAM | `PasswordSLAM2_2026!` | 10 |
| `mohamed.boukhatem` | Mohamed Boukhatem | GRP_Etudiants_SLAM | `PasswordSLAM2_2026!` | 10 |
| `klaudia.juhasz` | Klaudia Juhasz | GRP_Etudiants_SLAM | `PasswordSLAM2_2026!` | 10 |
| `denys.lyulchak` | Denys Lyulchak | GRP_Etudiants_SLAM | `PasswordSLAM2_2026!` | 10 |
| `kevin.senasson` | Kevin Senasson | GRP_Etudiants_SLAM | `PasswordSLAM2_2026!` | 10 |
| `yan.bourquard` | Yan Bourquard | GRP_Profs | `Prof_IRIS_2026!` | 20 |
| `stephanie.tanzi` | Stephanie Tanzi | GRP_Profs | `Prof_IRIS_2026!` | 20 |
| `terrence.ferut` | Terrence Ferut | GRP_Profs | `Prof_IRIS_2026!` | 20 |
| `hayk.kaymakcilar` | Hayk Kaymakcilar | GRP_Profs | `Prof_IRIS_2026!` | 20 |
| `raphael.tirintino` | Raphael Tirintino | GRP_Profs | `Prof_IRIS_2026!` | 20 |
| `melanie.lejeune` | Melanie Lejeune | GRP_Profs | `Prof_IRIS_2026!` | 20 |
| `lynda.hamidat` | Lynda Hamidat | GRP_Profs | `Prof_IRIS_2026!` | 20 |
| `marie.agnamazian` | Marie Agnamazian | GRP_Administration | `Admin_IRIS_2026!` | 30 |
| `enzo.sun` | Enzo Sun | GRP_Administration | `Admin_IRIS_2026!` | 30 |
| `invite.test` | Invite Test | GRP_Invites | `Invite_IRIS_2026!` | 40 |
| `nedj.belloum.admin` | Nedj Belloum Admin | GRP_IT_Admin + Domain Admins | `NVTech_Admin2026!` | 50 |
| `svc_nps` | Service NPS RADIUS | CompteService | `SvcNPS_IRIS_2026!` | — |

---

## 3. NPS / RADIUS — Clients et secrets partagés

| Client | IP | Secret partagé | Rôle |
|--------|-----|---------------|------|
| `AP-IRIS` | 192.168.50.24 | `RadiusAP_IRIS_2026!` | Point d'accès WiFi |
| `SW2-IRIS` | 192.168.50.2 | `RadiusSW_IRIS_2026!` | Switch 802.1X |
| `RT2-IRIS` | 192.168.50.1 | `RadiusRTR_IRIS_2026!` | Routeur WiFi |

---

## 4. Services Linux — URLs et identifiants

> **VM SRV-LINUX-IRIS : 192.168.50.20**  
> Accès depuis VLAN 50 Management uniquement (pare-feu UFW actif)

### 4.1 GLPI — Gestion de parc

| Paramètre | Valeur |
|-----------|--------|
| **URL** | http://192.168.50.20:8082 |
| Admin GLPI | `glpi` / `glpi` (défaut installation) |
| DB utilisateur | `glpi` |
| DB mot de passe | `GLPIDB_2026!` |
| DB root | `RootGLPI_2026!` |
| Base de données | `glpi` |

### 4.2 Nextcloud — Stockage collaboratif

| Paramètre | Valeur |
|-----------|--------|
| **URL** | http://192.168.50.20:8081 |
| Admin | `admin` / `NVTech_Admin2026!` |
| DB utilisateur | `nextcloud` |
| DB mot de passe | `NextcloudDB_IRIS_2026!` |
| DB root | `RootDB_IRIS_2026!` |
| Base de données | `nextcloud` |

### 4.3 Grafana — Dashboards monitoring

| Paramètre | Valeur |
|-----------|--------|
| **URL** | http://192.168.50.20:3000 |
| Admin | `admin` / `Grafana_IRIS_2026!` |

### 4.4 Prometheus — Collecte métriques

| Paramètre | Valeur |
|-----------|--------|
| **URL** | http://192.168.50.20:9090 |
| Authentification | Aucune (réseau interne uniquement) |

### 4.5 WireGuard VPN

| Paramètre | Valeur |
|-----------|--------|
| **URL Web UI** | http://192.168.50.20:51821 |
| Mot de passe UI | `WireGuard_IRIS_2026!` |
| Port UDP | 51820 |
| IP hôte | 192.168.50.20 |

### 4.6 Autres services (monitoring)

| Service | URL | Notes |
|---------|-----|-------|
| Node Exporter | http://192.168.50.20:9100/metrics | Métriques OS |
| CAdvisor | http://192.168.50.20:8083 | Métriques Docker |
| ClamAV | tcp://192.168.50.20:3310 | Antivirus (daemon) |

---

## 5. Équipements Cisco

### 5.1 Routeur RT2-IRIS (ISR 1941W)

| Paramètre | Valeur |
|-----------|--------|
| IP Management | 192.168.50.1 |
| `enable secret` | `NVTech_Admin2026!` |
| SSH user | `admin` / `NVTech_Admin2026!` |
| Domaine | `iris.local` |

```
ssh -l admin 192.168.50.1
enable → NVTech_Admin2026!
```

### 5.2 Switch SW2-IRIS (Catalyst 2960-S)

| Paramètre | Valeur |
|-----------|--------|
| IP Management | 192.168.50.2 |
| `enable secret` | `NVTech_Admin2026!` |
| SSH user | `admin` / `NVTech_Admin2026!` |

```
ssh -l admin 192.168.50.2
enable → NVTech_Admin2026!
```

---

## 6. Intégration LDAP (pour GLPI / Nextcloud)

| Paramètre | Valeur |
|-----------|--------|
| Serveur LDAP | `ldap://192.168.50.10:389` |
| Base DN | `DC=mediaschool,DC=local` |
| Bind DN (compte service) | `CN=svc_nps,OU=CompteService,OU=Serveurs,DC=mediaschool,DC=local` |
| Bind password | `SvcNPS_IRIS_2026!` |
| Filtre utilisateurs | `(&(objectClass=user)(memberOf=CN=GRP_Profs,...))` |

---

## 7. Résumé IPs infrastructure

| Équipement | IP | Rôle |
|------------|-----|------|
| DC-IRIS-01 | **192.168.50.10** | AD DS + DNS + DHCP + NPS |
| SRV-LINUX-IRIS | **192.168.50.20** | Docker (GLPI, Nextcloud, etc.) |
| RT2-IRIS | **192.168.50.1** | Routeur inter-VLAN + NAT |
| SW2-IRIS | **192.168.50.2** | Switch 802.1X |
| AP-IRIS | **192.168.50.24** | WiFi 802.1X |

| VLAN | Réseau | Usage |
|------|--------|-------|
| 10 | 192.168.10.0/24 | Étudiants (SISR + SLAM) |
| 20 | 192.168.20.0/24 | Professeurs |
| 30 | 192.168.30.0/24 | Administration école |
| 40 | 192.168.40.0/24 | Invités / Visiteurs |
| 50 | 192.168.50.0/24 | Management IT (serveurs) |
| 99 | 192.168.99.0/24 | Quarantaine PRE_AUTH |

---

## 8. Vérifications rapides (commandes de test)

### Sur DC-IRIS-01 (PowerShell via WinRM)
```powershell
# AD
Get-ADDomain | Select DomainMode, Forest
Get-ADUser -Filter * | Measure-Object   # → ≥ 26 comptes

# DHCP
Get-DhcpServerv4Scope | Select Name, ScopeId, State

# NPS
Get-Service IAS | Select Status
netsh nps show client
netsh nps show np

# DNS
Resolve-DnsName dc-iris-01.mediaschool.local
```

### Sur SRV-LINUX-IRIS (SSH)
```bash
# Docker
docker ps --format "table {{.Names}}\t{{.Status}}"

# Tests HTTP
curl -s -o /dev/null -w "%{http_code}" http://localhost:8082  # GLPI → 200
curl -s -o /dev/null -w "%{http_code}" http://localhost:8081  # Nextcloud → 302
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000  # Grafana → 302
curl -s -o /dev/null -w "%{http_code}" http://localhost:9090  # Prometheus → 302

# Ping DC
ping -c 2 192.168.50.10
```

---

*Document généré pour l'épreuve E5 BTS SIO SISR — MEDIASCHOOL Nice*  
*⚠️ Ce document ne doit pas être diffusé en dehors de l'environnement de test*
