# Annexe Technique — RP-01 IRIS Nice
## Configurations commentées et références

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

## A6 — WiFi Option A vs Option B — Questions jury anticipées

**Q : Pourquoi avoir choisi l'Option A (Multi-SSID) plutôt que l'Option B (SSID unique + VLAN dynamique) ?**
> L'Option B (SSID unique + `aaa-override` + Tunnel-Pvt-Group-ID RADIUS) est la solution théoriquement idéale. Cependant, le Cisco C9105AXI-E fonctionne en mode **EWC FlexConnect local switching** — et cette combinaison est connue comme **incompatible en IOS-XE 17.9.x**. Les tentatives de connexion aboutissaient systématiquement à une exclusion client avec le motif "VLAN failure". L'Option A a été retenue comme contournement éprouvé, compatible avec l'architecture déployée.

**Q : Quelles sont les limites de l'Option A ?**
> La principale limite est qu'un utilisateur peut théoriquement se connecter à un SSID qui ne correspond pas à son profil (ex: un étudiant sur IRIS-PROFS). NPS authentifie la personne (vérifie que le compte AD existe et est actif) mais n'effectue pas de vérification de groupe sur le SSID. La mitigation est assurée par les ACL inter-VLAN sur RT2-IRIS qui limitent ce que chaque VLAN peut faire.

**Q : Comment aurait-on déployé l'Option B en production ?**
> Option B nécessite soit un WLC centralisé (Cisco Catalyst Center / ex-DNA Center), soit de passer l'AP en mode **Local** (non FlexConnect). En mode Local, l'AP tunnele tout le trafic vers le WLC central, qui effectue le placement VLAN — ce qui est la configuration standard des déploiements WiFi d'entreprise à grande échelle.

**Q : Pourquoi `aaa-override` était-il activé par défaut sur les nouvelles policies ?**
> C'est le comportement par défaut d'EWC lors de la création de nouvelles wireless profile policies. Il faut explicitement le désactiver avec `no aaa-override` après `shutdown`. Ce paramètre par défaut est contre-intuitif en mode FlexConnect.

**Q : Quelle est la différence entre `DOT1X-IRIS` et `RADIUS-DOT1X` dans les WLANs ?**
> `DOT1X-IRIS` est le nom de la vraie méthode AAA configurée sur l'AP (`aaa authentication dot1x DOT1X-IRIS group NPS-DC-IRIS-GROUP`). `RADIUS-DOT1X` était un nom incorrect référencé dans les fichiers de backup mais qui n'existait pas comme méthode AAA valide sur l'AP. Les WLANs qui utilisaient `RADIUS-DOT1X` ne contactaient jamais le serveur RADIUS — aucune erreur n'est levée, les paquets sont juste abandonnés silencieusement.

---

## A7 — Commandes de vérification rapide AP2-IRIS

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
! Vérifier Cisco filaire
show running-config
show vlan brief
show ip nat translations
show dot1x all summary

! Vérifier AP2-IRIS EWC
show wlan summary
show wireless profile policy summary
show wireless client summary
show wireless exclusionlist
show running-config | include authentication-list
show wireless profile policy detail POLICY-PROFS
```
