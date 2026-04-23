# Procédure d'Utilisation — RP-01 IRIS Nice
## Guide de déploiement pour technicien

**Version :** 1.0  
**Date :** Mars 2026  
**Auteur :** Nedjmeddine Belloum  
**Public cible :** Technicien informatique niveau débutant/intermédiaire  

---

## Prérequis

Avant de commencer, vérifier que vous disposez de :

- VirtualBox 7.x installé
- Vagrant 2.x installé
- 16 Go RAM minimum disponibles sur la machine hôte
- 60 Go d'espace disque libre
- Connexion Internet active (téléchargement des boxes Vagrant)
- Ce dossier de projet copié sur votre machine

---

## Étape 1 — Démarrage des machines virtuelles

Ouvrir un terminal PowerShell dans le dossier du projet, puis :

```powershell
# Démarrer toutes les VMs
vagrant up

# Vérifier le statut
vagrant status
```

Les VMs démarrent dans cet ordre :
1. **DC-IRIS-01** (Windows Server 2022) — environ 5 minutes
2. **SRV-LINUX-IRIS** (Ubuntu 22.04) — environ 3 minutes

> **Note :** Si une VM ne démarre pas, relancer avec `vagrant up --provision`

---

## Étape 2 — Configuration du contrôleur de domaine

Se connecter à DC-IRIS-01 :

```powershell
vagrant rdp dc-iris-01
# ou via VirtualBox → double-clic sur DC-IRIS-01
# Identifiants : Administrator / NVTech_Admin2026!
```

Exécuter les scripts dans l'ordre. **Chaque script nécessite un redémarrage avant le suivant :**

```powershell
# Script 1 : Installation des rôles (AD DS, DNS, DHCP, NPS)
vagrant provision dc-iris-01 --provision-with install-roles
# Attendre le redémarrage automatique...

# Connexion → puis Script 2 : Promotion du contrôleur de domaine
vagrant provision dc-iris-01 --provision-with configure-ad
# Attendre le redémarrage automatique...

# Connexion → puis Script 3 : Configuration DHCP
vagrant provision dc-iris-01 --provision-with configure-dhcp
# Pas de redémarrage requis

# Script 4 : Configuration NPS/RADIUS
vagrant provision dc-iris-01 --provision-with configure-nps

# Script 5 : Création des utilisateurs et groupes AD
vagrant provision dc-iris-01 --provision-with create-users

# Script 6 : Application des GPOs
vagrant provision dc-iris-01 --provision-with configure-gpo
```

---

## Étape 3 — Vérification AD DS

Sur DC-IRIS-01, ouvrir **Active Directory Users and Computers** et vérifier :

- Le domaine `mediaschool.local` est visible
- Les OUs suivantes existent : `Etudiants`, `Profs`, `Administration`, `Serveurs`, `PostesSalle`, `PostesAdmin`, `CompteService`
- Des utilisateurs sont présents dans chaque OU

Tester la résolution DNS :

```powershell
nslookup dc-iris-01.mediaschool.local
# Doit retourner : 192.168.50.10
```

---

## Étape 4 — Vérification NPS

Sur DC-IRIS-01, ouvrir **Network Policy Server** (NPS) depuis Server Manager :

1. Dans **RADIUS Clients** : vérifier que `AP-IRIS`, `SW2-IRIS`, `RT2-IRIS` sont présents
2. Dans **Network Policies** : vérifier que 6 politiques sont présentes et **activées**
3. Les politiques doivent être dans l'ordre suivant :
   - NP_IT_Admin (priorité 1)
   - NP_Administration (priorité 2)
   - NP_Profs (priorité 3)
   - NP_Etudiants (priorité 4)
   - NP_Invites (priorité 5)
   - NP_Default_PreAuth (priorité 6)

---

## Étape 5 — Vérification des services Linux

Se connecter à SRV-LINUX-IRIS :

```powershell
vagrant ssh srv-linux-iris
```

Vérifier les conteneurs Docker :

```bash
docker compose ps
```

Tous les conteneurs doivent afficher l'état **running**.

Tester l'accès aux services depuis un navigateur (remplacer l'IP si nécessaire) :

| Service | URL | Identifiants par défaut |
|---------|-----|------------------------|
| Nextcloud | http://192.168.50.20:8081 | admin / NVTech_Admin2026! |
| GLPI | http://192.168.50.20:8082 | glpi / glpi |
| Grafana | http://192.168.50.20:3000 | admin / Grafana_IRIS_2026! |
| Prometheus | http://192.168.50.20:9090 | — |

> **Important :** Changer tous les mots de passe par défaut avant la mise en production.

---

## Étape 6 — Configuration des équipements Cisco

Appliquer les configurations depuis les fichiers du dossier `cisco/` :

**Sur SW2-IRIS (Catalyst 2960-S) :**

```
enable
configure terminal
! Copier-coller le contenu de cisco/SW2-IRIS_config.txt
```

**Sur RT2-IRIS (ISR 1941W) :**

```
enable
configure terminal
! Copier-coller le contenu de cisco/RT2-IRIS_config.txt
```

Vérifications après configuration :

```
show vlan brief              ! Vérifier VLANs 10,20,30,40,50,99
show interfaces trunk        ! Vérifier trunk SW2→RT2
show ip nat translations     ! Vérifier règles NAT
```

---

## Étape 7 — Test d'authentification 802.1X

Connecter un poste de test sur un port accès du SW2-IRIS (Fa0/10 à Fa0/19) :

1. Le poste doit être configuré pour utiliser l'authentification 802.1X (PEAP-MSCHAPv2)
2. Entrer les identifiants d'un étudiant AD (ex : `etudiant01` / `Etudiant01_2026!`)
3. Vérifier dans l'**Observateur d'événements** de DC-IRIS-01 (NPS logs) que l'authentification a réussi (événement 6272)
4. Vérifier que le poste a reçu une IP en 192.168.10.x

---

## Dépannage courant

### La VM DC-IRIS-01 ne démarre pas
```powershell
vagrant destroy dc-iris-01 -f
vagrant up dc-iris-01
```

### NPS n'authentifie pas
1. Vérifier que svc_nps est dans le groupe **RAS and IAS Servers**
2. Vérifier que NPS est enregistré dans AD : `netsh nps show registered`
3. Consulter l'Observateur d'événements → Applications and Services Logs → Microsoft → Windows → Network Policy Server

### Les conteneurs Docker ne démarrent pas
```bash
cd /vagrant
docker compose logs
docker compose down && docker compose up -d
```

### Problème NAT (DC ne joigne pas Internet)
Vérifier sur RT2-IRIS :
```
show ip nat translations
show access-lists NAT_LIST
```
Le réseau 192.168.50.0/24 doit être dans la liste (CORRECTION RP01 appliquée).

---

## Arrêt propre de l'infrastructure

```powershell
# Arrêter toutes les VMs proprement
vagrant halt

# Ou supprimer complètement (données perdues)
vagrant destroy -f
```

---
