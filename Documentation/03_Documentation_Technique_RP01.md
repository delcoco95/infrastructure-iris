# Documentation Technique — RP-01 IRIS Nice
## Infrastructure Sécurisée Windows Server 2022

**Référence :** IRIS-NICE-2024-RP01  
**Version :** 2.0 — Déploiement validé en lab  
**Date :** Avril 2026  
**Auteur :** Nedjmeddine Belloum — BTS SIO SISR  
**Établissement :** MEDIASCHOOL Nice  

---

## 1. Contexte et objectifs

### 1.1 Contexte

L'établissement MEDIASCHOOL Nice dispose d'une infrastructure réseau obsolète basée sur Linux (OpenLDAP + FreeRADIUS). Le projet RP-01 vise à migrer vers une architecture moderne Microsoft Windows Server 2022, offrant une meilleure intégration, une gestion centralisée et une sécurité renforcée.

### 1.2 Objectifs

- Déployer un contrôleur de domaine Active Directory (AD DS)
- Implémenter l'authentification réseau 802.1X via NPS/RADIUS
- Assigner dynamiquement les VLANs selon le profil utilisateur
- Maintenir les services applicatifs Linux (GLPI, Nextcloud, Grafana)
- Sécuriser l'accès réseau par segmentation VLAN et politiques de groupe

---

## 2. Architecture générale

### 2.1 Schéma d'adressage IP

| VLAN | Nom | Réseau | Passerelle | DHCP Range | Usage |
|------|-----|--------|------------|------------|-------|
| 10 | ETUDIANTS | 192.168.10.0/24 | 192.168.10.1 | .100 - .200 | Postes étudiants |
| 20 | PROFS | 192.168.20.0/24 | 192.168.20.1 | .100 - .200 | Postes enseignants |
| 30 | ADMINISTRATION | 192.168.30.0/24 | 192.168.30.1 | .100 - .200 | Postes admin |
| 40 | GUEST | 192.168.40.0/24 | 192.168.40.1 | .100 - .200 | Visiteurs |
| 50 | MANAGEMENT_IT | 192.168.50.0/24 | 192.168.50.1 | .50 - .254 | Infra IT |
| 99 | PRE_AUTH | 192.168.99.0/24 | 192.168.99.1 | .100 - .200 | Quarantaine |

> **Note critique :** VLAN 50 = Management IT (anciennement VLAN 99 dans l'ancienne infra Linux). VLAN 99 = quarantaine PRE_AUTH (rôle inversé). Cette numérotation est intentionnelle et diffère de l'ancienne infrastructure.

### 2.2 Inventaire des équipements

| Équipement | Rôle | IP Management | OS/Version |
|------------|------|--------------|------------|
| DC-IRIS-01 | AD DS + DNS + DHCP + NPS | 192.168.50.10 | Windows Server 2022 Std |
| SRV-LINUX-IRIS | Docker (GLPI, Nextcloud, etc.) | 192.168.50.20 | Ubuntu 22.04 LTS |
| SW2-IRIS | Switch accès + 802.1X | 192.168.50.2 | Cisco Catalyst 2960-S IOS 15.2 |
| RT2-IRIS | Routeur inter-VLAN + NAT | 192.168.50.1 | Cisco ISR 1941W IOS 15.2 |
| AP-IRIS | Point d'accès WiFi | 192.168.50.24 | Cisco AIR-CAP2702I |

---

## 3. Active Directory Domain Services

### 3.1 Domaine

- **Nom de domaine :** mediaschool.local
- **Nom NetBIOS :** MEDIASCHOOL
- **Niveau fonctionnel forêt/domaine :** Windows Server 2016
- **Mode DSRM :** mot de passe NVTech_Admin2026!

### 3.2 Structure OU

```
mediaschool.local
├── Etudiants
│   ├── SISR
│   └── SLAM
├── Profs
├── Administration
├── Serveurs
│   ├── CompteService      ← svc_nps ici
│   └── Windows
├── PostesSalle            ← GPO Étudiants liée
├── PostesAdmin            ← GPO Profs liée
├── Groupes
└── Invites
```

### 3.3 Groupes de sécurité principaux

| Groupe | Type | Membres |
|--------|------|---------|
| GRP_Etudiants_SISR | Global Security | Étudiants SISR |
| GRP_Etudiants_SLAM | Global Security | Étudiants SLAM |
| GRP_Profs | Global Security | Enseignants |
| GRP_Administration | Global Security | Personnel admin |
| GRP_IT_Admin | Global Security | Techniciens IT |
| GRP_Invites | Global Security | Visiteurs |

### 3.4 Comptes de service

| Compte | OU | Usage | Groupes |
|--------|----|-------|---------|
| svc_nps | CompteService | Authentification NPS | RAS and IAS Servers |

---

## 4. NPS / RADIUS (802.1X)

### 4.1 Clients RADIUS

| Nom | IP | Secret partagé |
|-----|----|---------------|
| AP-IRIS | 192.168.50.24 | RadiusAP_IRIS_2026! |
| SW2-IRIS | 192.168.50.2 | RadiusSW_IRIS_2026! |
| RT2-IRIS | 192.168.50.1 | RadiusRTR_IRIS_2026! |

### 4.2 Politiques réseau NPS

| Priorité | Nom | Condition | Attribut VLAN |
|----------|-----|-----------|---------------|
| 1 | NP_IT_Admin | GRP_IT_Admin | VLAN 50 |
| 2 | NP_Administration | GRP_Administration | VLAN 30 |
| 3 | NP_Profs | GRP_Profs | VLAN 20 |
| 4 | NP_Etudiants | GRP_Etudiants_SISR ou GRP_Etudiants_SLAM | VLAN 10 |
| 5 | NP_Invites | GRP_Invites | VLAN 40 |
| 6 | NP_Default_PreAuth | (catch-all) | VLAN 99 |

### 4.3 Attributs RADIUS pour l'assignation VLAN

Chaque politique injecte 3 attributs Vendor-Specific :

```
Tunnel-Type         = 13 (VLAN)
Tunnel-Medium-Type  = 6 (IEEE 802)
Tunnel-Private-Group-ID = <ID VLAN>
```

### 4.4 Méthode d'authentification

- **Protocole :** PEAP-MSCHAPv2
- **Certificat :** Auto-signé (lab) — en production, utiliser un certificat PKI d'entreprise

---

## 5. DHCP

Chaque scope VLAN est configuré avec :
- Plage d'adresses dynamiques
- Option 3 (Router) = adresse de la passerelle VLAN
- Option 6 (DNS) = 192.168.50.10 (DC-IRIS-01)
- Durée de bail : 8h (VLAN 99 : 1h)

---

## 6. GPO et sécurité

### 6.1 Group Policy Objects

| GPO | OU cible | Paramètres principaux |
|-----|----------|----------------------|
| GPO-SEC-Postes-Etudiants | OU=PostesSalle | Pas Control Panel, verrouillage 10min, pas d'installation logiciel |
| GPO-SEC-Postes-Profs | OU=PostesAdmin | Verrouillage 15min |
| GPO-SEC-Serveurs | OU=Serveurs | Firewall ON, SMB Signing, désactivation NetBIOS |
| GPO-SEC-PasswordPolicy | Domaine racine | Politique de mots de passe domaine |

### 6.2 Fine-Grained Password Policies

| FGPP | Appliqué à | Min. longueur | Complexité | Expiration | Blocage |
|------|-----------|---------------|------------|------------|---------|
| FGPP-Etudiants | GRP_Etudiants_SISR + GRP_Etudiants_SLAM | 8 | Oui | 90 jours | 5 tentatives |
| FGPP-Admins | GRP_IT_Admin | 12 | Oui | 60 jours | 3 tentatives |

---

## 7. Services Linux (Docker)

### 7.1 Architecture Docker

Tous les services tournent sur SRV-LINUX-IRIS via Docker Compose. Les données persistantes sont stockées dans `/opt/iris/`.

| Service | Image | Port | Description |
|---------|-------|------|-------------|
| GLPI | diouxx/glpi:latest | 8082 | Gestion de parc ITIL |
| Nextcloud | nextcloud:28-apache | 8081 | Stockage collaboratif |
| WireGuard | weejewel/wg-easy | 51820 UDP + 51821 TCP | VPN admin |
| Prometheus | prom/prometheus:v2.48.1 | 9090 | Collecte métriques |
| Grafana | grafana/grafana:10.2.3 | 3000 | Dashboards monitoring |
| Node Exporter | prom/node-exporter:v1.7.0 | 9100 | Métriques OS |
| CAdvisor | gcr.io/cadvisor/cadvisor:v0.47.2 | 8083 | Métriques Docker |
| ClamAV | clamav/clamav:1.3_base | 3310 | Antivirus |

### 7.2 Intégration LDAP/AD

GLPI et Nextcloud sont configurés pour s'authentifier via LDAP contre l'Active Directory :

- **Serveur LDAP :** ldap://192.168.50.10:389
- **Base DN :** dc=mediaschool,dc=local
- **Bind DN :** CN=svc_nps,OU=CompteService,OU=Serveurs,DC=mediaschool,DC=local

---

## 8. Sécurité réseau

### 8.1 Segmentation VLAN

Chaque catégorie d'utilisateurs est isolée dans son VLAN. Les échanges inter-VLAN sont contrôlés par les ACL du RT2-IRIS.

### 8.2 Quarantaine PRE_AUTH (VLAN 99)

Tout équipement non authentifié est placé en VLAN 99. Depuis ce VLAN :
- ✅ DHCP autorisé
- ✅ DNS autorisé (vers DC uniquement)
- ✅ RADIUS autorisé (vers DC)
- ✅ HTTP/HTTPS autorisés (portail captif possible)
- ❌ Accès aux VLANs internes bloqué

### 8.3 Sécurité Cisco

- SSH v2 uniquement (Telnet désactivé)
- Accès VTY limité au VLAN 50
- DHCP Snooping activé
- Dynamic ARP Inspection activé
- BPDUGuard sur tous les ports accès
- Ports non utilisés désactivés en VLAN 99

---

## 9. Supervision

### 9.1 Stack Prometheus + Grafana

Prometheus collecte les métriques toutes les 15 secondes auprès de :
- Node Exporter (métriques OS Linux)
- CAdvisor (métriques conteneurs Docker)

Grafana affiche les dashboards de supervision accessible sur http://192.168.50.20:3000.

### 9.2 Logs NPS

Les événements d'authentification NPS sont consultables dans :
`Observateur d'événements → Applications and Services Logs → Microsoft → Windows → Network Policy Server`

- Événement **6272** = Authentification accordée
- Événement **6273** = Authentification refusée

---

## 10. Annexe — Comptes et mots de passe

| Compte | Usage | Mot de passe |
|--------|-------|-------------|
| Administrator (local) | Admin Windows local | NVTech_Admin2026! |
| DSRM | Restauration AD | NVTech_Admin2026! |
| nedj.belloum.admin | Admin domaine | NVTech_Admin2026! |
| svc_nps | Service NPS | SvcNPS_IRIS_2026! |
| Vagrant box | SSH | vagrant/vagrant |

> **⚠️ En production :** Modifier tous les mots de passe. Utiliser un gestionnaire de secrets (HashiCorp Vault, etc.).

---

*Document rédigé pour l'épreuve E5 BTS SIO SISR — MEDIASCHOOL Nice*

---

## 8. Résultats de déploiement lab (Avril 2026)

### 8.1 Environnement de validation

| Élément | Détail |
|---------|--------|
| Hyperviseur | VirtualBox 7.x + Vagrant |
| DC-IRIS-01 box | gusztavvargadr/windows-server-2022-standard |
| SRV-LINUX-IRIS box | ubuntu/jammy64 |
| Réseau privé | 192.168.50.0/24 (virtualbox__intnet: vlan_management) |
| Date de déploiement | Avril 2026 |

### 8.2 Résultats scripts de provisioning

| Script | Description | Statut | Notes |
|--------|-------------|--------|-------|
| 01_install_roles.ps1 | AD DS, DNS, DHCP, NPAS | ✅ Succès | Rôles installés, redémarrage automatique |
| 02_configure_ad.ps1 | Promotion DC, domaine mediaschool.local | ✅ Succès | DomainMode = Windows2016Domain |
| 03_configure_dhcp.ps1 | 6 scopes VLAN 10/20/30/40/50/99 | ✅ Succès | DHCP autorisé dans AD (Enterprise Admin requis) |
| 04_configure_nps.ps1 | NPS AD, 3 clients RADIUS, 6 politiques | ✅ Succès | netsh utilisé (cmdlets PS limités sur Server 2022) |
| 05_create_users.ps1 | 17 OUs, 6 groupes, 25+ utilisateurs | ✅ Succès | |
| 06_configure_gpo.ps1 | 4 GPOs de sécurité | ✅ Succès | GPO-SEC-Serveurs + GPO-SEC-PasswordPolicy liées |

### 8.3 Problèmes résolus lors du déploiement

| Problème | Cause | Solution |
|---------|-------|----------|
| Add-DhcpServerInDC "Failed to initialize AD resources" | vagrant non membre de Enterprise Admins | Add-ADGroupMember "Enterprise Admins" vagrant |
| New-NpsRadiusClient -Enabled \True param invalide | Module Nps Server 2022 n'a pas -Enabled | Remplacement par 
etsh nps add client |
| 
etsh nps add registeredserver domain=... retourne "Element not found" | Syntaxe avec args explicites incorrecte | 
etsh nps add registeredserver sans arguments |
| Scopes DHCP VLAN50/99 manquants | Script échouait avant création complète | Ajout vérification existence + continue |
| ClamAV redémarre en boucle (lab) | VM 2 Go RAM insuffisants | Comportement normal en lab — OK en prod (≥ 4 Go) |

### 8.4 Services Linux opérationnels

| Service | Conteneur | Statut lab | URL |
|---------|-----------|-----------|-----|
| GLPI | glpi | ✅ HTTP 200 | http://192.168.50.20:8082 |
| Nextcloud | nextcloud | ✅ HTTP 302 | http://192.168.50.20:8081 |
| Grafana | grafana | ✅ HTTP 302 | http://192.168.50.20:3000 |
| Prometheus | prometheus | ✅ HTTP 302 | http://192.168.50.20:9090 |
| WireGuard | wireguard | ✅ Running | :51820/51821 |
| Node Exporter | node-exporter | ✅ Running | :9100 |
| CAdvisor | cadvisor | ✅ Healthy | :8083 |
| ClamAV | clamav | ⚠️ Restarting | RAM insuffisante lab |

### 8.5 Connectivité inter-VMs validée

- dc-iris → srv-linux (192.168.50.20) : **ping OK** (21ms)
- srv-linux → dc-iris (192.168.50.10) : **ping OK** (1.19ms, 0% loss)
- Réseau privé lan_management : **opérationnel**

---

*Validation lab complète — Prêt pour déploiement en environnement physique MEDIASCHOOL Nice*
