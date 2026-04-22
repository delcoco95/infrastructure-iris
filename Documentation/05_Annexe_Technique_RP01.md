# Annexe Technique — RP-01 IRIS Nice
## Configurations commentées et références

**Version :** 1.0  
**Auteur :** Nedjmeddine Belloum — BTS SIO SISR  

---

## A1 — Références des scripts PowerShell

### 01_install_roles.ps1

Ce script installe tous les rôles Windows Server nécessaires en une seule commande :

```powershell
# AD DS = Active Directory Domain Services
# DNS = Résolution de noms internes
# DHCP = Attribution IP automatique par VLAN
# NPAS = Network Policy and Access Services (NPS/RADIUS)
# RSAT = Outils d'administration à distance
Install-WindowsFeature -Name AD-Domain-Services,DNS,DHCP,NPAS,RSAT-AD-Tools `
    -IncludeManagementTools
```

### 02_configure_ad.ps1

La promotion du DC crée la forêt mediaschool.local. Le paramètre `SafeModeAdministratorPassword` correspond au mot de passe DSRM (Directory Services Restore Mode) — à conserver précieusement.

### 03_configure_dhcp.ps1

Chaque scope VLAN est créé avec sa plage et ses options. Le scope VLAN 50 exclut les adresses .1 à .30 (réservées aux équipements fixes : RT=.1, SW=.2, DC=.10, SRV=.20).

### 04_configure_nps.ps1 (script créé de zéro)

Ce script était absent du projet original. Il effectue :
1. L'enregistrement de NPS dans l'AD (`netsh nps add registeredserver`)
2. La création des 3 clients RADIUS
3. La création de 6 politiques réseau avec les attributs VLAN RADIUS

Les attributs RADIUS pour l'assignation VLAN sont des **Tunnel Attributes** (RFC 3580) :
- `64` = Tunnel-Type, valeur `13` (VLAN)
- `65` = Tunnel-Medium-Type, valeur `6` (IEEE 802)
- `81` = Tunnel-Private-Group-ID, valeur = numéro du VLAN en string

### 06_configure_gpo.ps1 (script créé de zéro)

Ce script était absent du projet original. Il crée et lie 4 GPOs, puis définit 2 Fine-Grained Password Policies. Les FGPP permettent d'avoir des politiques de mots de passe différentes pour les étudiants (moins stricte) et les administrateurs (plus stricte), ce qui n'est pas possible avec la politique de mots de passe du domaine (unique).

---

## A2 — Explication de la correction critique VLAN

### Ancienne infrastructure (Linux)
```
VLAN 99 = Management (192.168.99.0/24)  ← ancienne numérotation
VLAN 10 = Étudiants
```

### Nouvelle infrastructure (Windows Server 2022)
```
VLAN 50 = Management IT (192.168.50.0/24)  ← RENOMMÉ et renuméroté
VLAN 99 = PRE_AUTH quarantaine             ← NOUVEAU rôle
VLAN 10 = Étudiants (inchangé)
```

**Impact :** Si les VLANs n'avaient pas été mis à jour, le DC-IRIS-01 et tous les équipements infrastructure auraient été en VLAN 99 (quarantaine), rendant l'authentification 802.1X impossible.

### Correction NAT appliquée sur RT2-IRIS

**Problème :** Sans NAT sur VLAN 50, le DC-IRIS-01 (192.168.50.10) ne pouvait pas accéder à Internet pour :
- Télécharger les rôles Windows
- Activer Windows Server
- Synchroniser l'heure via NTP public
- Récupérer les mises à jour de sécurité

**Correction :** Ajout de `permit 192.168.50.0 0.0.0.255` dans la liste d'accès `NAT_LIST` du RT2-IRIS.

---

## A3 — Architecture réseau Docker (docker-compose.yml)

Les conteneurs sont organisés en 3 réseaux Docker logiques :

```
frontend    — Nextcloud, GLPI, Grafana, WireGuard (accessibles depuis LAN)
backend     — Bases de données MariaDB, ClamAV (isolation interne)
monitoring  — Prometheus, Grafana, Node Exporter, CAdvisor
```

La séparation frontend/backend garantit que les bases de données ne sont pas accessibles directement depuis le réseau externe.

---

## A4 — Questions jury anticipées

**Q : Pourquoi NPS plutôt que FreeRADIUS ?**
> NPS est natif à Windows Server, s'intègre directement avec AD sans configuration LDAP supplémentaire, et ses logs sont dans l'Event Viewer (standard Windows). FreeRADIUS nécessiterait une VM Linux supplémentaire et une config LDAP vers l'AD.

**Q : Que se passe-t-il si NPS tombe en panne ?**
> Les clients 802.1X en cours de session conservent leur VLAN tant que leur bail 802.1X n'expire pas. Les nouvelles connexions sont bloquées ou placées en VLAN 99 (selon la config fail-open/fail-close du switch). Il faudrait un NPS secondaire en production.

**Q : Pourquoi VLAN 99 en quarantaine et non en blocage total ?**
> L'Access-Accept en VLAN 99 permet une expérience utilisateur plus douce (portail captif possible) et évite les blocages réseau qui empêcheraient même l'authentification RADIUS de se terminer. Le VLAN 99 est filtré par ACL pour bloquer l'accès aux VLANs internes.

**Q : La politique NP_Default_PreAuth représente-t-elle un risque ?**
> Non, car le VLAN 99 est isolé des VLANs internes par ACL sur le RT2-IRIS. Un équipement non authentifié ne peut accéder qu'à Internet et aux serveurs RADIUS/DNS. C'est volontairement un Access-Accept (et non Access-Reject) pour permettre les reconnexions.

**Q : Pourquoi diouxx/glpi et non une image officielle ?**
> L'image officielle GLPI n'existait pas au moment de la conception. diouxx/glpi est l'image community la plus maintenue. En production, il faudrait soit utiliser une installation native, soit maintenir une image interne contrôlée.

---

## A5 — Commandes de vérification rapide

```powershell
# Vérifier AD DS
Get-ADDomain | Select Forest, DomainMode
dcdiag /test:replications

# Vérifier NPS
Get-Service IAS
netsh nps show client
netsh nps show policy

# Vérifier DHCP
Get-DhcpServerv4Scope | Select ScopeId, Name, State

# Vérifier GPO
Get-GPO -All | Select DisplayName, GpoStatus
Get-ADFineGrainedPasswordPolicy -Filter * | Select Name, MinPasswordLength
```

```bash
# Vérifier Docker (sur SRV-LINUX-IRIS)
docker compose ps
docker compose logs --tail=50
docker stats --no-stream
```

```
! Vérifier Cisco
show running-config
show vlan brief
show ip nat translations
show dot1x all summary
```

---

*Document rédigé pour l'épreuve E5 BTS SIO SISR — MEDIASCHOOL Nice*
