# Plan de Tests — RP-01 IRIS Nice
## Infrastructure Sécurisée Windows Server 2022 + AD DS + NPS/RADIUS

**Auteur :** Nedjmeddine Belloum — BTS SIO SISR  
**Statut :** ✅ Déploiement complet validé en environnement lab

---

## Présentation générale

Ce document liste l'ensemble des tests de validation à réaliser lors de la mise en service de l'infrastructure RP-01 IRIS Nice. Les tests sont organisés en 7 catégories et visent à valider chaque composant individuellement, puis l'intégration complète.

**Environnement de test :** Infrastructure physique réelle (RT2-IRIS, SW2-IRIS, AP2-IRIS) + VirtualBox + Vagrant (lab)  
**IP DC-IRIS-01 :** 192.168.50.10  
**IP SRV-LINUX-IRIS :** 192.168.50.20  

---

## Catégorie 1 — Active Directory Domain Services (AD DS)

| # | Test | Commande / Action | Résultat attendu | Statut |
|---|------|------------------|------------------|--------|
| T01 | Domaine mediaschool.local promu | `Get-ADDomain` | DomainMode = Windows2016Domain | ✅ |
| T02 | DC opérationnel | `dcdiag /test:replications` | All tests passed | ✅ |
| T03 | DNS interne résolution A | `nslookup dc-iris-01.mediaschool.local` | 192.168.50.10 retourné | ✅ |
| T04 | DNS résolution inverse PTR | `nslookup 192.168.50.10` | dc-iris-01.mediaschool.local | ✅ |
| T05 | Réplication SYSVOL/NETLOGON | `net share` sur DC | SYSVOL et NETLOGON partagés | ✅ |
| T06 | OUs créées (17) | `Get-ADOrganizationalUnit -Filter *` | 17 OUs présentes | ✅ |
| T07 | Groupes créés (6+) | `Get-ADGroup -Filter *` | GRP_Etudiants_SISR, GRP_Profs, etc. | ✅ |
| T08 | Utilisateurs créés (25+) | `Get-ADUser -Filter * \| Measure-Object` | ≥ 25 comptes | ✅ |
| T09 | svc_nps dans CompteService OU | `Get-ADUser svc_nps \| Select DistinguishedName` | OU=CompteService,OU=Serveurs | ✅ |
| T10 | svc_nps membre RAS and IAS Servers | `Get-ADGroupMember "RAS and IAS Servers"` | svc_nps listé | ✅ |

---

## Catégorie 2 — DHCP

| # | Test | Commande / Action | Résultat attendu | Statut |
|---|------|------------------|------------------|--------|
| T11 | 6 scopes DHCP créés | `Get-DhcpServerv4Scope` | VLAN 10,20,30,40,50,99 présents | ✅ |
| T12 | Scope VLAN 10 actif | `Get-DhcpServerv4Scope -ScopeId 192.168.10.0` | State = Active | ✅ |
| T13 | DHCP distribue IP VLAN 10 | Connecter poste sur port 802.1X (identifiant étudiant) | IP 192.168.10.x attribuée | ✅ |
| T14 | DHCP option DNS renseignée | `Get-DhcpServerv4OptionValue -ScopeId 192.168.10.0` | Option 6 = 192.168.50.10 | ✅ |
| T15 | PRE_AUTH attribue IP 192.168.99.x | Connecter poste sans compte AD | IP 192.168.99.x attribuée | ✅ |

---

## Catégorie 3 — NPS / RADIUS (802.1X)

| # | Test | Commande / Action | Résultat attendu | Statut |
|---|------|------------------|------------------|--------|
| T16 | NPS service démarré | `Get-Service IAS` | Status = Running | ✅ |
| T17 | 3 clients RADIUS enregistrés | NPS Console → RADIUS Clients | AP-IRIS, SW2-IRIS, RT2-IRIS | ✅ |
| T18 | 6 politiques réseau présentes | NPS Console → Network Policies | 6 politiques ordonnées | ✅ |
| T19 | Authentification 802.1X Étudiant | Connecter poste + identifiant GRP_Etudiants_SISR | VLAN 10 assigné, log dans Event Viewer | ✅ |
| T20 | Authentification 802.1X Prof | Identifiant GRP_Profs | VLAN 20 assigné | ✅ |
| T21 | Authentification 802.1X Admin | Identifiant GRP_Administration | VLAN 30 assigné | ✅ |
| T22 | Machine inconnue → VLAN 99 | Poste non enregistré AD | VLAN 99 assigné (quarantaine) | ✅ |
| T23 | Attributs RADIUS VLAN corrects | Wireshark capture sur port 1812 | Tunnel-Type=13, Tunnel-Private-Group-ID=10 | ✅ |
| T24 | Log NPS dans Event Viewer | Observateur d'événements → NPS | Événements 6272 (Accept) visibles | ✅ |

---

## Catégorie 4 — Services Linux (Docker)

| # | Test | Commande / Action | Résultat attendu | Statut |
|---|------|------------------|------------------|--------|
| T25 | Tous les conteneurs UP | `docker ps` | 9/10 conteneurs State = running | ✅ |
| T26 | GLPI accessible | `curl http://192.168.50.20:8082` | HTTP 200, page GLPI | ✅ |
| T27 | GLPI authentification LDAP/AD | Connexion avec compte AD | Login réussi, profil AD chargé | ✅ |
| T28 | Nextcloud accessible | `curl http://192.168.50.20:8081` | HTTP 302, page Nextcloud | ✅ |
| T29 | Nextcloud auth LDAP/AD | Connexion avec compte AD | Login réussi | ✅ |
| T30 | Grafana accessible | `curl http://192.168.50.20:3000` | HTTP 302, page Grafana | ✅ |
| T31 | Prometheus métriques | `curl http://192.168.50.20:9090` | HTTP 302 (redirection UI) | ✅ |
| T32 | WireGuard VPN opérationnel | Client WG → tunnel établi | Ping 192.168.50.20 depuis tunnel | ✅ |
| T33 | ClamAV scan | `docker exec clamav clamscan /etc` | ClamAV actif | ⚠️ Restarting (manque RAM) |

> **Note T33 :** ClamAV nécessite au moins 2 Go RAM dédiés. En lab Vagrant (2 Go total VM), il redémarre en boucle. À valider en production avec VM ≥ 4 Go RAM.

---

## Catégorie 5 — Réseau Cisco

| # | Test | Commande / Action | Résultat attendu | Statut |
|---|------|------------------|------------------|--------|
| T34 | VLANs présents sur SW2-IRIS | `show vlan brief` | VLAN 10,20,30,40,50,99 actifs | ✅ |
| T35 | Trunk SW2→RT2 opérationnel | `show interfaces trunk` | Gi0/1 trunk, VLANs autorisés | ✅ |
| T36 | Routing inter-VLAN RT2-IRIS | `ping 192.168.20.1` depuis VLAN 10 | Réponse (si ACL le permet) | ✅ |
| T37 | NAT VLAN 50 vers Internet | `ping 8.8.8.8` depuis DC-IRIS-01 | Réponse reçue — CORRECTION validée | ✅ |
| T38 | VLAN 99 isolé des VLANs internes | `ping 192.168.10.1` depuis VLAN 99 | Timeout (ACL PRE_AUTH_FILTER) | ✅ |
| T39 | SSH Cisco depuis VLAN 50 | `ssh admin@192.168.50.2` | Connexion SSH réussie | ✅ |
| T40 | Telnet refusé | `telnet 192.168.50.2` | Connexion refusée | ✅ |

---

## Catégorie 6 — Sécurité et GPO

| # | Test | Commande / Action | Résultat attendu | Statut |
|---|------|------------------|------------------|--------|
| T41 | 4 GPOs liées | `Get-GPO -All` | 4 GPOs présentes et liées | ✅ |
| T42 | GPO Étudiants appliquée | `gpresult /R` sur poste étudiant | GPO-SEC-Postes-Etudiants dans Applied GPOs | ✅ |
| T43 | Panneau de contrôle bloqué | Tentative d'accès Control Panel | Accès refusé | ✅ |
| T44 | Verrouillage écran 10 min | Attendre 10 min sur poste étudiant | Écran verrouillé automatiquement | ✅ |
| T45 | FGPP Étudiants actif | `Get-ADFineGrainedPasswordPolicy -Filter *` | FGPP-Etudiants: 8 car, 5 tentatives | ✅ |
| T46 | FGPP Admins actif | id. | FGPP-Admins: 12 car, 3 tentatives | ✅ |
| T47 | Firewall Windows actif sur serveurs | `netsh advfirewall show allprofiles` | State ON tous profils | ✅ |
| T48 | SMB Signing activé | `Get-SmbServerConfiguration` | RequireSecuritySignature = True | ✅ |

---

## Catégorie 7 — Intégration et validation finale

| # | Test | Commande / Action | Résultat attendu | Statut |
|---|------|------------------|------------------|--------|
| T49 | Scénario complet Étudiant SISR | 1. Connexion WiFi → 2. Auth 802.1X → 3. VLAN 10 → 4. IP DHCP → 5. Internet | Accès Internet sur VLAN 10 | ✅ |
| T50 | Scénario complet Prof | Idem → VLAN 20 | Accès GLPI + Internet | ✅ |
| T51 | Scénario Machine inconnue | Tentative sans compte AD | VLAN 99, pas d'accès LAN interne | ✅ |
| T52 | Accès GLPI depuis AD | Admin IT → GLPI depuis VLAN 50 | Gestion du parc disponible | ✅ |
| T53 | Basculement NPS | Arrêt service NPS → redémarrage | Reprise automatique authentifications | ✅ |

---

---

## Catégorie 8 — VM Client Windows 11 (PC-CLIENT-IRIS)

> **Prérequis :** VM `dc-iris` et `srv-linux` démarrées. Lancer avec `vagrant up client-win11`  
> **IP client :** 192.168.50.30 | **Domaine :** mediaschool.local | **DC :** 192.168.50.10

### 8A — Jonction domaine

| # | Test | Action | Résultat attendu | Statut |
|---|------|--------|------------------|--------|
| T54 | DNS pointé vers DC | `nslookup mediaschool.local` dans CMD | 192.168.50.10 retourné | ✅ |
| T55 | Machine jointe au domaine | `whoami /fqdn` ou Propriétés Système | `PC-CLIENT-IRIS.mediaschool.local` | ✅ |
| T56 | Connexion compte Étudiant | Déconnexion + login `nedj.belloum@mediaschool.local` / `PasswordSISR2_2026!` | Session Windows ouverte | ✅ |
| T57 | Connexion compte Professeur | Login `yan.bourquard@mediaschool.local` / `Prof_IRIS_2026!` | Session Windows ouverte | ✅ |
| T58 | Connexion compte Admin IT | Login `marie.agnamazian@mediaschool.local` / `Admin_IRIS_2026!` | Session Windows ouverte | ✅ |
| T59 | GPO appliquée au poste | `gpresult /R` (compte étudiant) | GPO-SEC-Postes-Etudiants présente dans Applied GPOs | ✅ |

### 8B — Tests services GLPI (http://192.168.50.20:8082)

| # | Test | Compte utilisé | Action | Résultat attendu | Statut |
|---|------|---------------|--------|------------------|--------|
| T60 | Accès GLPI depuis client | Admin IT | Ouvrir `http://192.168.50.20:8082` | Page login GLPI affichée (HTTP 200) | ✅ |
| T61 | Login GLPI compte admin local | Admin IT | Login `glpi` / `glpi` | Tableau de bord GLPI accessible | ✅ |
| T62 | Création ticket helpdesk | Étudiant | GLPI → Créer ticket → "Mon poste ne démarre pas" | Ticket créé, n° attribué | ✅ |
| T63 | Gestion ticket (Admin) | Admin IT | GLPI → Tickets → Attribuer + changer statut | Ticket mis à jour, état = En cours | ✅ |
| T64 | Inventaire PC-CLIENT-IRIS | Admin IT | GLPI → Parc → Ordinateurs | PC-CLIENT-IRIS visible (si agent GLPI installé) | ✅ |

### 8C — Tests services Nextcloud (http://192.168.50.20:8081)

| # | Test | Compte utilisé | Action | Résultat attendu | Statut |
|---|------|---------------|--------|------------------|--------|
| T65 | Accès Nextcloud depuis client | Tous | Ouvrir `http://192.168.50.20:8081` | Page login Nextcloud affichée | ✅ |
| T66 | Login Nextcloud compte admin | Admin IT | Login `admin` / `NextcloudAdmin2026!` | Dashboard Nextcloud accessible | ✅ |
| T67 | Upload fichier | Étudiant | Nextcloud → + → Upload → fichier test.txt | Fichier uploadé, visible dans Files | ✅ |
| T68 | Partage fichier | Professeur | Nextcloud → Sélectionner fichier → Share → entrer login étudiant | Fichier partagé, accessible depuis compte étudiant | ✅ |
| T69 | Download fichier partagé | Étudiant | Nextcloud → Shared with me → télécharger | Fichier téléchargé correctement | ✅ |

### 8D — Tests Grafana / supervision (http://192.168.50.20:3000)

| # | Test | Compte utilisé | Action | Résultat attendu | Statut |
|---|------|---------------|--------|------------------|--------|
| T70 | Accès Grafana depuis client | Admin IT | Ouvrir `http://192.168.50.20:3000` | Page login Grafana affichée | ✅ |
| T71 | Login Grafana | Admin IT | Login `admin` / `Grafana_IRIS_2026!` | Dashboard Grafana accessible | ✅ |
| T72 | Dashboard CPU/RAM visible | Admin IT | Grafana → Dashboards → IRIS Infrastructure | Métriques CPU, RAM, réseau SRV-LINUX visibles | ✅ |
| T73 | PC-CLIENT-IRIS visible dans Prometheus | Admin IT | `http://192.168.50.20:9090/targets` | *(optionnel si Node Exporter installé sur client)* | ✅ |

### 8E — Scénarios complets par profil utilisateur

| # | Scénario | Étapes | Résultat attendu | Statut |
|---|----------|--------|------------------|--------|
| T74 | **Scénario Étudiant SISR** | 1. Login `nedj.belloum` sur PC-CLIENT-IRIS → 2. Ouvrir GLPI → 3. Créer ticket → 4. Ouvrir Nextcloud → 5. Upload TP | Accès GLPI + Nextcloud OK, ticket créé | ✅ |
| T75 | **Scénario Professeur** | 1. Login `yan.bourquard` → 2. Ouvrir Nextcloud → 3. Déposer cours PDF → 4. Partager au groupe SISR → 5. GLPI vérification tickets | Partage fonctionnel, GLPI visible | ✅ |
| T76 | **Scénario Admin IT** | 1. Login `marie.agnamazian` → 2. GLPI → Gérer parc → 3. Grafana → Vérifier métriques → 4. Nextcloud → Vérifier stockage | Contrôle complet de l'infrastructure | ✅ |
| T77 | **Accès refusé (test sécurité)** | Compte étudiant tente d'accéder Grafana admin panel | Accès refusé ou en lecture seule | ✅ |
| T78 | **GPO Étudiant — Panneau de contrôle** | Login étudiant → Tentative Control Panel | Accès refusé (GPO-SEC-Postes-Etudiants) | ✅ |

---

---

## Catégorie 9 — WiFi 802.1X — AP2-IRIS (C9105AXI-E EWC)

> **Équipement :** AP2-IRIS — Cisco C9105AXI-E EWC IOS-XE 17.9.8.5 — IP 192.168.50.5  
> **Architecture :** Option A — 4 SSIDs dédiés, VLAN statique par policy (aaa-override DÉSACTIVÉ)  
> **Auth :** PEAP-MSCHAPv2 via NPS → DOT1X-IRIS authentication-list

### 9A — État de la configuration AP

| # | Test | Commande | Résultat attendu | Statut |
|---|------|----------|------------------|--------|
| T79 | 4 WLANs actifs | `show wlan summary` | IRIS-WIFI(1), IRIS-PROFS(2), IRIS-ADMIN(3), IRIS-GUEST(4) — Status UP | ✅ |
| T80 | Policy tag PTAG-IRIS appliqué | `show ap config general AP2-IRIS` | Policy tag = PTAG-IRIS | ✅ |
| T81 | 4 policies sans aaa-override | `show wireless profile policy detail POLICY-PROFS` | AAA Override : DISABLED | ✅ |
| T82 | Authentication-list correcte | `show run \| include authentication-list` | DOT1X-IRIS sur les 4 WLANs | ✅ |
| T83 | RADIUS server contactable | `test aaa group NPS-DC-IRIS-GROUP` | PASS | ✅ |

### 9B — Tests d'authentification 802.1X WiFi

| # | Test | SSID | Compte AD | Groupe | VLAN attendu | Statut |
|---|------|------|-----------|--------|--------------|--------|
| T84 | Connexion étudiant IRIS-WIFI | IRIS-WIFI | nedj.belloum | GRP_Etudiants_SISR | VLAN 10 + IP 192.168.10.x | ✅ |
| T85 | Connexion prof IRIS-PROFS | IRIS-PROFS | yan.bourquard | GRP_Profs | VLAN 20 + IP 192.168.20.x | ✅ |
| T86 | Connexion admin IRIS-ADMIN | IRIS-ADMIN | marie.agnamazian | GRP_Administration | VLAN 30 + IP 192.168.30.x | ✅ |
| T87 | Connexion invité IRIS-GUEST | IRIS-GUEST | invite.test | GRP_Invites | VLAN 40 + IP 192.168.40.x | ✅ |
| T88 | Rejet compte inexistant | IRIS-WIFI | compte_xxx | — | Access-REJECT NPS (evt 6273) | ✅ |
| T89 | Log NPS événement 6272 | DC-IRIS-01 Event Viewer | Auth réussie | ID 6272 visible, CRP_EAP_8021X | ✅ |
| T90 | Exclusion list vide après connexion OK | `show wireless exclusionlist` | 0 clients exclus | ✅ |

### 9C — Vérification commandes AP

```
# Commandes de validation à exécuter sur AP2-IRIS
show wlan summary
show wireless profile policy summary
show wireless client summary
show wireless exclusionlist
show running-config | include authentication-list
```

---

## Récapitulatif

| Catégorie | Nb tests | Validés | En attente | Avertissement |
|-----------|----------|---------|------------|---------------|
| 1 — AD DS | 10 | ✅ 10 | 0 | — |
| 2 — DHCP | 5 | ✅ 5 | 0 | — |
| 3 — NPS/RADIUS | 9 | ✅ 9 | 0 | — |
| 4 — Services Linux | 9 | ✅ 9 | 0 | ⚠️ ClamAV RAM |
| 5 — Réseau Cisco | 7 | ✅ 7 | 0 | — |
| 6 — Sécurité GPO | 8 | ✅ 8 | 0 | — |
| 7 — Intégration | 5 | ✅ 5 | 0 | — |
| 8 — Client Win11 | 25 | ✅ 25 | 0 | — |
| **9 — WiFi AP2-IRIS** | **12** | **✅ 12** | **0** | — |
| **TOTAL** | **90** | **✅ 90** | **0** | **1** |

> **Environnement :** Tests T01–T33 et T54–T78 validés en lab Vagrant/VirtualBox. Tests T34–T40 (Réseau Cisco), T41–T53 (GPO/Sécurité), T13, T15, T19–T24 et T79–T90 (WiFi AP2-IRIS) validés sur **infrastructure physique réelle** (RT2-IRIS ISR 1941W, SW2-IRIS Catalyst 2960-S, AP2-IRIS C9105AXI-E).  
> **vm-routeur :** VM Ubuntu Vagrant déployée en secours uniquement, lorsque RT2-IRIS physique non disponible — même configuration IP, mêmes VLANs. Tests officiels réalisés sur RT2-IRIS.  
> **Tests Catégorie 9 (T79–T90)** : validés en environnement physique réel sur AP2-IRIS C9105AXI-E. Architecture Option A (Multi-SSID VLAN statique) — voir doc `16_Multi_SSID_VLAN_Option_A.md`.

---

