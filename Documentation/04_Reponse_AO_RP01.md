# Réponse à Appel d'Offres — RP-01 IRIS Nice
## Modernisation de l'Infrastructure Réseau MEDIASCHOOL Nice

**Référence AO :** IRIS-NICE-2024-RP01  
**Date :** Juin 2026  
**Soumissionnaire :** Nedjmeddine Belloum — BTS SIO SISR  

---

## 1. Compréhension du besoin

MEDIASCHOOL Nice souhaite moderniser son infrastructure réseau en remplaçant l'ancienne solution Linux/OpenLDAP/FreeRADIUS par une architecture Microsoft Windows Server 2022, plus adaptée à la gestion d'un établissement d'enseignement supérieur.

Les enjeux identifiés sont :
- **Sécurité** : segmentation réseau par profil utilisateur (VLAN dynamique 802.1X)
- **Administration centralisée** : gestion unifiée des comptes (AD DS) et des politiques (GPO)
- **Disponibilité des services** : GLPI, Nextcloud, supervision Prometheus/Grafana
- **Conformité** : isolation des équipements non conformes (VLAN 99 PRE_AUTH)

---

## 2. Solution proposée

### 2.1 Architecture retenue

Nous proposons une architecture à deux serveurs virtuels :

**DC-IRIS-01** (Windows Server 2022 Standard) :
- Active Directory Domain Services — référentiel centralisé des identités
- DNS interne — résolution du domaine mediaschool.local
- DHCP — attribution automatique des adresses IP par VLAN
- NPS/RADIUS — authentification 802.1X et assignation VLAN dynamique

**SRV-LINUX-IRIS** (Ubuntu Server 22.04 LTS + Docker) :
- GLPI — gestion de parc et helpdesk
- Nextcloud — partage de fichiers sécurisé
- Stack monitoring (Prometheus + Grafana)
- WireGuard VPN — accès distant sécurisé pour les techniciens
- ClamAV — protection antivirus

### 2.2 Justification des choix technologiques

| Choix | Justification |
|-------|--------------|
| Windows Server 2022 AD DS | Standard industrie, intégration native 802.1X/NPS, GPO riches |
| NPS vs FreeRADIUS | Natif Windows, gestion graphique, journalisation Event Viewer |
| Docker sur Ubuntu | Légèreté, isolation, facilité de mise à jour des applications |
| PEAP-MSCHAPv2 | Compatible avec tous les clients Windows sans certificat client |
| VLANs dynamiques | Isolation par profil, réduction surface d'attaque |

### 2.3 Sécurité by design

La solution applique le principe de **moindre privilège** à plusieurs niveaux :

1. **Niveau réseau** : VLAN par catégorie d'utilisateurs, VLAN 99 comme quarantaine
2. **Niveau accès** : 802.1X obligatoire, tout équipement non authentifié isolé
3. **Niveau Active Directory** : OUs dédiées, FGPP différenciées par profil
4. **Niveau applications** : Docker networks segmentés (frontend/backend/monitoring)
5. **Niveau Cisco** : ACL, DHCP Snooping, ARP Inspection, SSH uniquement

---

## 3. Plan de migration

### Phase 1 — Préparation (Semaine 1)
- Inventaire du parc existant
- Export utilisateurs OpenLDAP → import AD
- Sauvegarde configuration FreeRADIUS
- Déploiement lab de validation (Vagrant)

### Phase 2 — Déploiement DC (Semaine 2)
- Installation Windows Server 2022
- Promotion contrôleur de domaine
- Configuration DNS, DHCP, NPS
- Création des utilisateurs et GPO

### Phase 3 — Services applicatifs (Semaine 2-3)
- Déploiement Docker sur SRV-LINUX-IRIS
- Migration données GLPI et Nextcloud
- Configuration intégration LDAP/AD
- Tests de connectivité

### Phase 4 — Réseau Cisco (Semaine 3)
- Application configuration 802.1X sur SW2-IRIS
- Configuration RADIUS sur RT2-IRIS
- Tests 802.1X par VLAN
- Validation segmentation

### Phase 5 — Recette et formation (Semaine 4)
- Exécution du plan de tests (53 tests)
- Correction des anomalies
- Formation utilisateurs administrateurs
- Documentation finale et remise

---

## 4. Garanties et livrables

### 4.1 Livrables inclus dans l'offre

- ✅ Vagrantfile (infrastructure as code, reproductible)
- ✅ 6 scripts PowerShell de déploiement automatisé
- ✅ 1 script bash + docker-compose.yml pour les services Linux
- ✅ Configurations complètes SW2-IRIS et RT2-IRIS
- ✅ Plan de tests (53 tests, 7 catégories)
- ✅ Documentation technique complète
- ✅ Procédure d'utilisation pour technicien

### 4.2 Performances attendues

- **Disponibilité cible** : 99,5% (maintenance programmée hors heures ouvrées)
- **Délai d'authentification 802.1X** : < 5 secondes
- **Bande passante** : aucune limitation interne entre VLANs autorisés

---

## 5. Référentiels et normes appliqués

| Norme/Référentiel | Application |
|-------------------|-------------|
| IEEE 802.1X | Authentification port réseau |
| RFC 2865/2866 | RADIUS Authentication + Accounting |
| RFC 3580 | 802.1X RADIUS VLAN |
| CIS Benchmarks Windows Server 2022 | Durcissement serveurs (GPO-SEC-Serveurs) |
| RGPD | Gestion des données personnelles étudiants |

---

*Offre soumise dans le cadre de l'épreuve E5 BTS SIO SISR — MEDIASCHOOL Nice*
