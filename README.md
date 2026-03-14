# Infrastructure réseau sécurisée — Réponse à l'appel d'offre IRIS

## 📋 Contexte

Dans le cadre d'un projet BTS SIO option SISR en équipe de 3, réponse à un appel d'offre réel de l'école IRIS Nice pour la conception et le déploiement d'une infrastructure réseau sécurisée. L'école ne disposait d'aucune segmentation réseau, d'aucune authentification individuelle et d'aucun environnement de virtualisation dédié à la formation.

**Équipe projet :**
- **Nedjmeddine Belloum** — Chef de projet, FreeRADIUS, OpenLDAP
- **Vincent Andreo** — Configuration Cisco (switch, routeur)
- **Julien Marcucci** — Services Docker, sécurité VM

---

## 🎯 Objectif

Concevoir et déployer une infrastructure réseau sécurisée répondant aux exigences suivantes :
- Segmentation réseau par profil utilisateur via 7 VLANs isolés
- Authentification individuelle 802.1X (filaire et WiFi) avec attribution dynamique des VLANs
- Déploiement de services via Docker (FreeRADIUS, OpenLDAP, Nextcloud)
- Budget maximum : 50 000 € — solution 100% open source
- Livraison d'une maquette PoC validée avant déploiement en production

---

## 🛠️ Technologies utilisées

| Technologie | Rôle |
|---|---|
| Cisco ISR 1900 | Routeur — Router-on-a-Stick (7 VLANs sur 1 interface) |
| Cisco Catalyst 2960S | Switch 48 ports — 802.1X sur chaque port accès |
| Cisco C9105AXI-E | Points d'accès WiFi PoE |
| FreeRADIUS | Serveur d'authentification RADIUS |
| OpenLDAP | Annuaire centralisé des utilisateurs |
| Docker & Docker Compose | Orchestration des services |
| WireGuard | VPN pour l'accès administrateur distant |
| ClamAV | Antivirus en temps réel |
| UFW / nftables | Pare-feu sur la VM Debian |
| Nextcloud + MariaDB | Stockage pédagogique partagé |

---

## ⚙️ Ce qui a été réalisé

### 1. Segmentation réseau — 7 VLANs

| VLAN | Nom | Réseau | Usage |
|---|---|---|---|
| 99 | Management | 192.168.99.0/26 | Équipements réseau (routeur, switch, serveur) |
| 10 | Administration | 192.168.10.0/24 | Personnel administratif |
| 20 | Professeurs | 192.168.20.0/24 | Corps enseignant |
| 30 | Étudiants | 192.168.30.0/24 | Tous les étudiants BTS SIO |
| 40 | Guests | 192.168.40.0/24 | Invités — accès Internet uniquement |
| 50 | WiFi 802.1X | 192.168.50.0/24 | Authentification WiFi individuelle |
| 60 | VMs TP | 192.168.60.0/24 | Machines virtuelles pédagogiques |

### 2. Architecture Cisco (Router-on-a-Stick)

```
Routeur ISR 1900 (trunk)
└── Sous-interfaces logiques par VLAN (802.1Q)
    └── Switch Catalyst 2960S
        ├── Ports accès avec 802.1X activé
        └── Port trunk vers le routeur
```

### 3. Authentification 802.1X — Flux complet

```
PC → Switch → FreeRADIUS → OpenLDAP → Attribution VLAN
 1. Le PC se connecte sur un port du switch
 2. Le switch envoie une requête RADIUS à FreeRADIUS
 3. FreeRADIUS interroge OpenLDAP (vérification credentials + OU)
 4. FreeRADIUS retourne l'ID du VLAN selon le profil
 5. Le switch configure automatiquement le port sur le bon VLAN
```

### 4. Services Docker déployés (VM Debian 12 — 192.168.99.21/26)

| Conteneur | Rôle |
|---|---|
| FreeRADIUS | Authentification + attribution VLAN dynamique |
| OpenLDAP | Annuaire (25 comptes : étudiants, profs, admins) |
| Nextcloud | Stockage pédagogique partagé |
| MariaDB | Base de données Nextcloud |
| WireGuard | VPN administration distante |
| ClamAV | Antivirus temps réel |
| UFW/nftables | Pare-feu VM |

### 5. Tests de validation réalisés

| Utilisateur | Profil | Résultat | VLAN attribué |
|---|---|---|---|
| nedj.belloum | Étudiant SISR | ✅ Access-Accept | VLAN 30 |
| yan.bourquard | Professeur | ✅ Access-Accept | VLAN 20 |
| admin1 | Administrateur IT | ✅ Access-Accept | VLAN 99 |
| user_inconnu | — | ✅ Access-Reject | Aucun |

### 6. Budget final

| Poste | Montant HT |
|---|---|
| Prestations (config, doc, formation) | 20 800 € |
| Matériel de redondance | 7 600 € |
| Licences logicielles | 0 € (100% open source) |
| **Total** | **28 400 €** |
| Enveloppe disponible | 50 000 € |
| **Économie réalisée** | **21 600 € (43%)** |

---

## ✅ Résultats obtenus

- Maquette PoC fonctionnelle validée sur matériel Cisco réel
- 7 VLANs isolés avec ACLs strictes opérationnels
- Authentification 802.1X filaire et WiFi validée bout en bout
- Attribution dynamique des VLANs depuis OpenLDAP opérationnelle
- Budget maîtrisé à 28 400 € sur 50 000 € d'enveloppe

---

## 🔗 Compétences BTS SIO mobilisées

| Compétence | Description |
|---|---|
| **B1.1** | Gérer le patrimoine informatique |
| **B1.2** | Répondre aux incidents (pare-feu, VPN, traçabilité) |
| **B1.4** | Travailler en mode projet (appel d'offre, RACI, planning agile) |
| **B1.5** | Mettre à disposition des utilisateurs un service informatique |

---

## 👤 Auteur

**Nedjmeddine Belloum** — BTS SIO option SISR — Chef de projet  
Centre de formation : Mediaschool Nice — IRIS  
Période : 23/02/2026 au 13/03/2026  
Portfolio : [https://delcoco95.github.io/mon-portfolio/](https://delcoco95.github.io/mon-portfolio/)
