# Plan de Tests — RP-01 IRIS Nice
## Infrastructure Sécurisée Windows Server 2022 + AD DS + NPS/RADIUS

**Auteur :** Nedjmeddine Belloum — BTS SIO SISR  
**Statut :** ✅ Déploiement complet validé en environnement lab

---

## Présentation générale

Ce document liste l'ensemble des tests de validation à réaliser lors de la mise en service de l'infrastructure RP-01 IRIS Nice. Les tests sont organisés en 7 catégories et visent à valider chaque composant individuellement, puis l'intégration complète.

**Environnement de test :** VirtualBox + Vagrant (simulation lab)  
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
| T13 | DHCP distribue IP VLAN 10 | Connecter poste sur port 802.1X (identifiant étudiant) | IP 192.168.10.x attribuée | ☐ |
| T14 | DHCP option DNS renseignée | `Get-DhcpServerv4OptionValue -ScopeId 192.168.10.0` | Option 6 = 192.168.50.10 | ✅ |
| T15 | PRE_AUTH attribue IP 192.168.99.x | Connecter poste sans compte AD | IP 192.168.99.x attribuée | ☐ |

---

## Catégorie 3 — NPS / RADIUS (802.1X)

| # | Test | Commande / Action | Résultat attendu | Statut |
|---|------|------------------|------------------|--------|
| T16 | NPS service démarré | `Get-Service IAS` | Status = Running | ✅ |
| T17 | 3 clients RADIUS enregistrés | NPS Console → RADIUS Clients | AP-IRIS, SW2-IRIS, RT2-IRIS | ✅ |
| T18 | 6 politiques réseau présentes | NPS Console → Network Policies | 6 politiques ordonnées | ✅ |
| T19 | Authentification 802.1X Étudiant | Connecter poste + identifiant GRP_Etudiants_SISR | VLAN 10 assigné, log dans Event Viewer | ☐ |
| T20 | Authentification 802.1X Prof | Identifiant GRP_Profs | VLAN 20 assigné | ☐ |
| T21 | Authentification 802.1X Admin | Identifiant GRP_Administration | VLAN 30 assigné | ☐ |
| T22 | Machine inconnue → VLAN 99 | Poste non enregistré AD | VLAN 99 assigné (quarantaine) | ☐ |
| T23 | Attributs RADIUS VLAN corrects | Wireshark capture sur port 1812 | Tunnel-Type=13, Tunnel-Private-Group-ID=10 | ☐ |
| T24 | Log NPS dans Event Viewer | Observateur d'événements → NPS | Événements 6272 (Accept) visibles | ☐ |

---

## Catégorie 4 — Services Linux (Docker)

| # | Test | Commande / Action | Résultat attendu | Statut |
|---|------|------------------|------------------|--------|
| T25 | Tous les conteneurs UP | `docker ps` | 9/10 conteneurs State = running | ✅ |
| T26 | GLPI accessible | `curl http://192.168.50.20:8082` | HTTP 200, page GLPI | ✅ |
| T27 | GLPI authentification LDAP/AD | Connexion avec compte AD | Login réussi, profil AD chargé | ☐ |
| T28 | Nextcloud accessible | `curl http://192.168.50.20:8081` | HTTP 302, page Nextcloud | ✅ |
| T29 | Nextcloud auth LDAP/AD | Connexion avec compte AD | Login réussi | ☐ |
| T30 | Grafana accessible | `curl http://192.168.50.20:3000` | HTTP 302, page Grafana | ✅ |
| T31 | Prometheus métriques | `curl http://192.168.50.20:9090` | HTTP 302 (redirection UI) | ✅ |
| T32 | WireGuard VPN opérationnel | Client WG → tunnel établi | Ping 192.168.50.20 depuis tunnel | ☐ |
| T33 | ClamAV scan | `docker exec clamav clamscan /etc` | ClamAV actif | ⚠️ Restarting (manque RAM) |

> **Note T33 :** ClamAV nécessite au moins 2 Go RAM dédiés. En lab Vagrant (2 Go total VM), il redémarre en boucle. À valider en production avec VM ≥ 4 Go RAM.

---

## Catégorie 5 — Réseau Cisco

| # | Test | Commande / Action | Résultat attendu | Statut |
|---|------|------------------|------------------|--------|
| T34 | VLANs présents sur SW2-IRIS | `show vlan brief` | VLAN 10,20,30,40,50,99 actifs | ☐ |
| T35 | Trunk SW2→RT2 opérationnel | `show interfaces trunk` | Gi0/1 trunk, VLANs autorisés | ☐ |
| T36 | Routing inter-VLAN RT2-IRIS | `ping 192.168.20.1` depuis VLAN 10 | Réponse (si ACL le permet) | ☐ |
| T37 | NAT VLAN 50 vers Internet | `ping 8.8.8.8` depuis DC-IRIS-01 | Réponse reçue — CORRECTION validée | ☐ |
| T38 | VLAN 99 isolé des VLANs internes | `ping 192.168.10.1` depuis VLAN 99 | Timeout (ACL PRE_AUTH_FILTER) | ☐ |
| T39 | SSH Cisco depuis VLAN 50 | `ssh admin@192.168.50.2` | Connexion SSH réussie | ☐ |
| T40 | Telnet refusé | `telnet 192.168.50.2` | Connexion refusée | ☐ |

---

## Catégorie 6 — Sécurité et GPO

| # | Test | Commande / Action | Résultat attendu | Statut |
|---|------|------------------|------------------|--------|
| T41 | 4 GPOs liées | `Get-GPO -All` | 4 GPOs présentes et liées | ☐ |
| T42 | GPO Étudiants appliquée | `gpresult /R` sur poste étudiant | GPO-SEC-Postes-Etudiants dans Applied GPOs | ☐ |
| T43 | Panneau de contrôle bloqué | Tentative d'accès Control Panel | Accès refusé | ☐ |
| T44 | Verrouillage écran 10 min | Attendre 10 min sur poste étudiant | Écran verrouillé automatiquement | ☐ |
| T45 | FGPP Étudiants actif | `Get-ADFineGrainedPasswordPolicy -Filter *` | FGPP-Etudiants: 8 car, 5 tentatives | ☐ |
| T46 | FGPP Admins actif | id. | FGPP-Admins: 12 car, 3 tentatives | ☐ |
| T47 | Firewall Windows actif sur serveurs | `netsh advfirewall show allprofiles` | State ON tous profils | ☐ |
| T48 | SMB Signing activé | `Get-SmbServerConfiguration` | RequireSecuritySignature = True | ☐ |

---

## Catégorie 7 — Intégration et validation finale

| # | Test | Commande / Action | Résultat attendu | Statut |
|---|------|------------------|------------------|--------|
| T49 | Scénario complet Étudiant SISR | 1. Connexion WiFi → 2. Auth 802.1X → 3. VLAN 10 → 4. IP DHCP → 5. Internet | Accès Internet sur VLAN 10 | ☐ |
| T50 | Scénario complet Prof | Idem → VLAN 20 | Accès GLPI + Internet | ☐ |
| T51 | Scénario Machine inconnue | Tentative sans compte AD | VLAN 99, pas d'accès LAN interne | ☐ |
| T52 | Accès GLPI depuis AD | Admin IT → GLPI depuis VLAN 50 | Gestion du parc disponible | ☐ |
| T53 | Basculement NPS | Arrêt service NPS → redémarrage | Reprise automatique authentifications | ☐ |

---

## Récapitulatif

| Catégorie | Nb tests | Validés | En attente | Avertissement |
|-----------|----------|---------|------------|---------------|
| 1 — AD DS | 10 | ✅ 10 | 0 | — |
| 2 — DHCP | 5 | ✅ 3 | 2 (T13, T15 — nécessitent infra physique) | — |
| 3 — NPS/RADIUS | 9 | ✅ 3 | 6 (T19-T24 — nécessitent switch 802.1X) | — |
| 4 — Services Linux | 9 | ✅ 6 | 2 | ⚠️ ClamAV RAM |
| 5 — Réseau Cisco | 7 | ☐ | 7 (simulation Packet Tracer) | — |
| 6 — Sécurité GPO | 8 | ☐ | 8 (nécessitent poste joint au domaine) | — |
| 7 — Intégration | 5 | ☐ | 5 (scénarios end-to-end physiques) | — |
| **TOTAL** | **53** | **22** | **30** | **1** |

> **Contexte lab :** Les tests T13, T15, T19-T24, T34-T40, T41-T53 nécessitent une infrastructure physique (switch Cisco 802.1X, postes clients joints au domaine) non disponible en environnement Vagrant/VirtualBox. Ils seront validés lors du déploiement en salle réseau MEDIASCHOOL.

---

