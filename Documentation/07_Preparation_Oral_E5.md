# 🎤 Préparation Oral E5 — RP-01 IRIS Nice
## BTS SIO SISR — Épreuve E5 — Présentation 2 minutes

**Candidat :** Nedjmeddine Belloum  
**Établissement :** MEDIASCHOOL Nice  
**Référence projet :** IRIS-NICE-2024-RP01  
**Version :** 2.0 — Mise à jour infrastructure Windows Server 2022

---

## 🎯 Pitch 2 minutes (à mémoriser)

> **[0:00 – 0:20] — Contexte (accroche)**

"Pour cette réalisation, j'étais chef de projet sur une infrastructure réseau complète pour l'école IRIS Nice — réponse à un appel d'offre réel, en équipe de 3. L'infrastructure existante était un réseau plat, sans segmentation, sans contrôle d'accès — un risque majeur pour un établissement accueillant 300 étudiants, enseignants et visiteurs."

---

> **[0:20 – 0:55] — Ce qu'on a construit**

"On a conçu et déployé une infrastructure sécurisée en 6 VLANs sur matériel Cisco réel — routeur ISR 1941W et switch Catalyst 2960-S.

Le cœur du projet : **l'authentification 802.1X avec NPS/RADIUS sur Windows Server 2022**. Chaque utilisateur se connecte avec ses propres identifiants Active Directory — les étudiants SISR et SLAM arrivent automatiquement sur le VLAN 10, les professeurs sur le VLAN 20, l'administration sur le 30. Un inconnu, sans compte AD, tombe sur le VLAN 99 de quarantaine — isolé du réseau interne.

Tout est automatisé : 6 scripts PowerShell provisionnent le DC en séquence — AD DS, DNS, DHCP, NPS, utilisateurs, et GPO de sécurité."

---

> **[0:55 – 1:25] — Services et sécurité**

"Sur le serveur Linux, 9 services tournent dans Docker : **GLPI** pour la gestion du parc informatique, **Nextcloud** pour le stockage pédagogique partagé, **WireGuard** pour le VPN admin, **Grafana + Prometheus** pour le monitoring en temps réel.

Sur la sécurité : Fine-Grained Password Policies différenciées par groupe, GPO de verrouillage de session, pare-feu Windows actif sur tous les serveurs, SSH uniquement depuis le VLAN 50 Management, SMB Signing activé."

---

> **[1:25 – 1:50] — Résultats validés**

"En environnement lab Vagrant/VirtualBox, tous les composants ont été validés : 6 scopes DHCP actifs, 3 clients RADIUS configurés, 6 politiques NPS opérationnelles, communication DC-Windows ↔ Serveur-Linux confirmée en moins de 2ms. Les 9 services Docker répondent. 22 tests sur 53 validables en lab — les 31 restants nécessitent le matériel physique Cisco."

---

> **[1:50 – 2:00] — Clôture**

"Ce projet m'a permis de maîtriser Windows Server 2022, la configuration 802.1X en profondeur, et l'automatisation d'infrastructure par scripts. Je suis prêt à détailler n'importe quel composant."

---

## ❓ Questions probables du jury — Réponses préparées

### Q1 : "Pourquoi Windows Server 2022 plutôt que Linux/FreeRADIUS ?"

**Réponse :**
> "L'ancienne infra Linux avec FreeRADIUS + OpenLDAP était fonctionnelle mais complexe à maintenir — pas d'interface graphique, chaque modification nécessitait une intervention manuelle dans des fichiers de config. Windows Server 2022 avec AD DS + NPS apporte une gestion centralisée via GUI et PowerShell, une intégration native 802.1X, et des GPO de sécurité qui n'ont pas d'équivalent simple sous Linux pour un établissement scolaire."

---

### Q2 : "Comment fonctionne le 802.1X concrètement ?"

**Réponse :**
> "Quand un utilisateur branche son PC sur un port du switch SW2-IRIS, le switch demande une authentification (EAP). L'utilisateur entre ses identifiants AD. Le switch les transmet au serveur NPS en RADIUS (port 1812). NPS vérifie l'identité dans Active Directory, puis consulte ses 6 politiques réseau — si l'utilisateur appartient à GRP_Etudiants_SISR, NPS répond 'Access-Accept' avec les attributs VLAN 10 : Tunnel-Type=VLAN, Tunnel-Medium-Type=802, Tunnel-Private-Group-ID=10. Le switch place le port dans le VLAN 10 et le DHCP distribue une IP en 192.168.10.x."

---

### Q3 : "Qu'est-ce que le VLAN 99 de quarantaine ?"

**Réponse :**
> "Tout appareil non reconnu — sans compte AD valide — est orienté vers le VLAN 99. Ce réseau 192.168.99.0/24 est isolé par ACL : accès Internet uniquement, aucun accès aux VLANs internes. Il permet d'identifier la machine, de procéder à une inscription avant de lui donner accès. C'est la politique NAC — Network Access Control."

---

### Q4 : "Comment avez-vous automatisé le déploiement ?"

**Réponse :**
> "Avec Vagrant + VirtualBox pour instancier les VMs, et 6 scripts PowerShell séquentiels pour le DC. Script 01 installe les rôles (Add-WindowsFeature), script 02 promeut le DC (Install-ADDSForest), script 03 configure le DHCP, script 04 le NPS via netsh, script 05 crée les OUs/groupes/utilisateurs, script 06 les GPO. Chaque script est idempotent — on peut le relancer sans dupliquer les objets."

---

### Q5 : "Quel problème avez-vous rencontré et comment l'avez-vous résolu ?"

**Réponse :**
> "Le plus complexe : l'autorisation DHCP dans l'AD échouait avec 'Failed to initialize directory service resources'. Après investigation, j'ai découvert deux causes : le conteneur CN=DhcpRoot n'existe pas automatiquement dans l'AD après promotion, et le compte vagrant n'était pas dans Enterprise Admins. Solution : j'ai ajouté vagrant au groupe Enterprise Admins, ouvert une nouvelle session WinRM pour forcer un nouveau token Kerberos, et relancé Add-DhcpServerInDC — qui a créé le conteneur et autorisé le serveur."

---

### Q6 : "Pourquoi NPS plutôt que FreeRADIUS ?"

**Réponse :**
> "NPS est intégré nativement à Windows Server — pas d'installation supplémentaire, configuration via netsh ou GUI MMC, et surtout intégration directe avec Active Directory sans connecteur LDAP externe. FreeRADIUS nécessite une configuration manuelle des attributs VLAN en fichiers texte. NPS gère les 6 attributs VLAN RADIUS (Tunnel-Type, Tunnel-Medium-Type, Tunnel-Private-Group-ID) directement depuis les politiques réseau."

---

### Q7 : "Que surveille Grafana ?"

**Réponse :**
> "Grafana se connecte à Prometheus qui collecte les métriques via deux exporters : Node Exporter pour les métriques OS du serveur Linux (CPU, RAM, disque, réseau) et CAdvisor pour les métriques des conteneurs Docker (CPU/RAM par conteneur). On peut suivre en temps réel l'état de tous les services et configurer des alertes si un seuil est dépassé."

---

## 📋 Chiffres clés à retenir

| Indicateur | Valeur |
|------------|--------|
| VLANs | 6 (10, 20, 30, 40, 50, 99) |
| Utilisateurs AD | 26 comptes (+ 2 comptes service) |
| OUs Active Directory | 17 |
| Scripts PowerShell | 6 (automatisation complète DC) |
| Clients RADIUS | 3 (AP, Switch, Routeur) |
| Politiques NPS | 6 (une par VLAN) |
| Services Docker | 9 (GLPI, Nextcloud, WireGuard, Grafana, Prometheus...) |
| Tests validés en lab | 22 / 53 |
| GPO de sécurité | 4 |
| Documents produits | 7 |

---

## 🗺️ Plan de l'architecture (à montrer au jury)

```
Internet
    │
[RT2-IRIS 192.168.50.1] — NAT + Routage inter-VLAN + 802.1X WiFi
    │ Trunk 802.1q
[SW2-IRIS 192.168.50.2] — Switch 802.1X (dot1x port-control auto)
    │
    ├── VLAN 50 (Management) ──── DC-IRIS-01 (192.168.50.10) ──── Windows Server 2022
    │                                                               AD DS + DNS + DHCP + NPS
    ├── VLAN 50 (Management) ──── SRV-LINUX-IRIS (192.168.50.20) — Ubuntu + Docker
    │                                                               GLPI · Nextcloud · Grafana
    ├── VLAN 10 (Étudiants)  ──── 192.168.10.100-200 (DHCP)
    ├── VLAN 20 (Profs)      ──── 192.168.20.100-200 (DHCP)
    ├── VLAN 30 (Admin école)──── 192.168.30.100-200 (DHCP)
    ├── VLAN 40 (Invités)    ──── 192.168.40.100-200 (DHCP)
    └── VLAN 99 (Quarantaine)──── 192.168.99.100-200 (DHCP) — Isolé par ACL
```

---

## ✅ Checklist avant oral

- [ ] Ouvrir VirtualBox — vérifier que `DC-IRIS-01` et `SRV-LINUX-IRIS` sont Running
- [ ] Tester WinRM : `Test-Connection 127.0.0.1 -Port 55985`
- [ ] Ouvrir http://192.168.50.20:8082 (GLPI) dans le navigateur
- [ ] Ouvrir http://192.168.50.20:3000 (Grafana) dans le navigateur
- [ ] Avoir le fichier `06_Credentials_Access_RP01.md` ouvert
- [ ] Avoir les schémas réseau (Annexe Technique) prêts
- [ ] Relire les 7 questions du jury ci-dessus

---

*Nedjmeddine Belloum — BTS SIO SISR — MEDIASCHOOL Nice — Épreuve E5 2026*
