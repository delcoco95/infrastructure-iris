# 🎤 Oral Pratique E5 — RP-01 IRIS Nice
## Présentation 5 à 10 minutes — Guide complet

**Candidat :** Nedjmeddine Belloum  
**Établissement :** MEDIASCHOOL Nice  
**Projet :** IRIS-NICE-2024-RP01 — Infrastructure sécurisée Windows Server 2022  
**Épreuve :** E5 BTS SIO SISR — Oral pratique  

---

## ⏱️ Plan minuté — Version 5 minutes

| Temps | Partie | Contenu |
|-------|--------|---------|
| 0:00 – 0:30 | Contexte & problème | Situation initiale, pourquoi ce projet |
| 0:30 – 1:30 | Architecture | Schéma, VLANs, équipements |
| 1:30 – 2:30 | Cœur technique — 802.1X | Fonctionnement AD + NPS + RADIUS |
| 2:30 – 3:30 | Automatisation | Scripts PowerShell + Docker |
| 3:30 – 4:15 | Sécurité | GPO, FGPP, pare-feu, ACL Cisco |
| 4:15 – 5:00 | Résultats & démo | Tests validés, live si possible |

---

## ⏱️ Plan minuté — Version 10 minutes

| Temps | Partie | Contenu |
|-------|--------|---------|
| 0:00 – 0:45 | Contexte & appel d'offres | Problème, équipe, mission |
| 0:45 – 2:00 | Architecture complète | Schéma, VLANs, choix techniques justifiés |
| 2:00 – 3:30 | AD DS & utilisateurs | Domaine, OUs, GPO, FGPP |
| 3:30 – 5:00 | NPS / RADIUS / 802.1X | Flux complet d'authentification |
| 5:00 – 6:30 | Services Linux Docker | GLPI, Nextcloud, Grafana, WireGuard |
| 6:30 – 7:30 | Automatisation Vagrant | Scripts PowerShell, idempotence |
| 7:30 – 8:30 | Sécurité by design | Moindre privilège, ACL, VLAN 99 |
| 8:30 – 9:30 | Démonstration live | Démarrer une VM, montrer un service |
| 9:30 – 10:00 | Bilan & compétences | Ce que j'ai appris, difficultés résolues |

---

## 🗣️ Script complet — 10 minutes

---

### 🟦 PARTIE 1 — Contexte et mission (0:45)

> *Ton : posé, confiant. Regard jury. Pas de lecture.*

"Bonjour. Je vais vous présenter ma réalisation RP-01 : le déploiement d'une infrastructure réseau sécurisée pour l'école IRIS Nice.

Le contexte : MEDIASCHOOL Nice avait un réseau plat — pas de segmentation, pas de contrôle d'accès. N'importe quel appareil connecté avait accès à tout le réseau. Avec 300 utilisateurs — étudiants, profs, administration, visiteurs — c'est un risque de sécurité majeur.

La mission : répondre à un appel d'offres réel, en équipe de 3, pour remplacer toute l'infrastructure par une solution Windows Server 2022 moderne, segmentée, et sécurisée."

---

### 🟦 PARTIE 2 — Architecture (1:15)

> *Montrer le schéma sur écran ou document. Pointer chaque élément.*

"Voici l'architecture que nous avons déployée.

```
Internet
    │
[RT2-IRIS — 192.168.50.1]   Cisco ISR 1941W — Routage inter-VLAN + NAT
    │ Trunk 802.1q
[SW2-IRIS — 192.168.50.2]   Cisco Catalyst 2960-S — 802.1X port-control
    │
    ├── VLAN 50 — DC-IRIS-01 (192.168.50.10) — Windows Server 2022
    ├── VLAN 50 — SRV-LINUX-IRIS (192.168.50.20) — Ubuntu + Docker
    ├── VLAN 10 — Étudiants     → 192.168.10.100-200
    ├── VLAN 20 — Professeurs   → 192.168.20.100-200
    ├── VLAN 30 — Administration → 192.168.30.100-200
    ├── VLAN 40 — Invités        → 192.168.40.100-200
    └── VLAN 99 — Quarantaine    → 192.168.99.100-200 (isolé par ACL)
```

Le serveur Windows héberge AD DS, DNS, DHCP et NPS. Le serveur Linux héberge 9 services Docker. Les deux sont dans le VLAN 50 Management — accessible uniquement depuis ce réseau."

---

### 🟦 PARTIE 3 — Active Directory et utilisateurs (1:30)

> *Ouvrir un terminal et lancer la commande si démo possible.*

"Le domaine **mediaschool.local** est administré par **DC-IRIS-01**. L'AD est structuré en 17 OUs :

- `OU=Utilisateurs` → sous-OUs par profil : Etudiants, Profs, Administration, Invités
- `OU=Serveurs` → machines serveurs et compte service NPS
- `OU=Ordinateurs` → postes clients

J'ai créé **26 comptes utilisateurs** répartis dans **6 groupes** — GRP_Etudiants_SISR, GRP_Etudiants_SLAM, GRP_Profs, GRP_Administration, GRP_Invites, GRP_IT_Admin.

Pour la politique de mots de passe, j'ai utilisé les **Fine-Grained Password Policies** — ça permet d'avoir des règles différentes par groupe :
- Étudiants : 8 caractères, expiration 90 jours, blocage après 5 tentatives
- Admins IT : 12 caractères, expiration 60 jours, blocage après 3 tentatives

```powershell
# Vérification live
Get-ADDomain | Select DomainMode, Forest
Get-ADUser -Filter * | Measure-Object
Get-ADFineGrainedPasswordPolicy -Filter * | Select Name, MinPasswordLength
```"

---

### 🟦 PARTIE 4 — NPS / RADIUS / 802.1X — le cœur du projet (1:30)

> *C'est la partie technique clé. Parler lentement et clairement.*

"C'est le cœur du projet. Voici le flux complet d'authentification 802.1X :

```
[PC Étudiant]
    │ 1. Branche le câble / se connecte au WiFi
    │
[SW2-IRIS / RT2-IRIS]
    │ 2. Détecte la connexion → envoie EAP-Request (demande d'identité)
    │
[PC Étudiant]
    │ 3. Répond avec son login AD (ex: nedj.belloum)
    │
[SW2-IRIS] ──── RADIUS Access-Request ────► [DC-IRIS-01 — NPS :1812]
    │                                              │
    │                               4. NPS vérifie dans Active Directory
    │                               5. NPS consulte ses 6 politiques réseau
    │                               6. Correspond à : GRP_Etudiants_SISR
    │                                              │
[SW2-IRIS] ◄─── RADIUS Access-Accept ────── [NPS]
    │            + Tunnel-Type = VLAN (13)
    │            + Tunnel-Medium-Type = 802 (6)
    │            + Tunnel-Private-Group-ID = 10
    │
    │ 7. Switch place le port dans VLAN 10
    │
[PC Étudiant] ──── DHCPDISCOVER ────► [DC-IRIS-01 — DHCP]
    │                                  Scope VLAN10 → IP 192.168.10.x
```

J'ai configuré **3 clients RADIUS** — le point d'accès WiFi, le switch, le routeur — avec chacun son secret partagé. Et **6 politiques NPS**, une par VLAN, ordonnées par priorité.

```bash
# Vérification live
netsh nps show client
netsh nps show np
Get-Service IAS | Select Status
```"

---

### 🟦 PARTIE 5 — Services Linux Docker (1:00)

> *Montrer docker ps si la VM est accessible.*

"Sur le serveur Ubuntu, Docker Compose orchestre 9 services :

| Service | Port | Rôle |
|---------|------|------|
| **GLPI** | :8082 | Gestion de parc ITIL — tickets, inventaire |
| **Nextcloud** | :8081 | Stockage pédagogique partagé |
| **Grafana** | :3000 | Dashboards monitoring temps réel |
| **Prometheus** | :9090 | Collecte métriques (+ Node Exporter + CAdvisor) |
| **WireGuard** | :51820/51821 | VPN admin accès distant |
| **ClamAV** | :3310 | Antivirus centralisé |

Les données sont persistantes dans `/opt/iris/` — si le conteneur redémarre, rien n'est perdu.

```bash
# Vérification live
docker ps --format 'table {{.Names}}\t{{.Status}}'
curl -s -o /dev/null -w 'GLPI: %{http_code}\n' http://localhost:8082
curl -s -o /dev/null -w 'Grafana: %{http_code}\n' http://localhost:3000
```"

---

### 🟦 PARTIE 6 — Automatisation avec Vagrant et PowerShell (1:00)

> *Montrer un script si possible. Insister sur l'idempotence.*

"Tout le déploiement est automatisé. Vagrant instancie les deux VMs en une commande. Six scripts PowerShell séquentiels provisionnent le DC :

| Script | Rôle |
|--------|------|
| `01_install_roles.ps1` | Installe AD DS, DNS, DHCP, NPAS |
| `02_configure_ad.ps1` | Promeut le DC, crée le domaine mediaschool.local |
| `03_configure_dhcp.ps1` | Crée les 6 scopes VLAN |
| `04_configure_nps.ps1` | Configure NPS, clients RADIUS, 6 politiques |
| `05_create_users.ps1` | Crée 17 OUs, 6 groupes, 26 utilisateurs |
| `06_configure_gpo.ps1` | Crée et lie 4 GPO + 2 FGPP |

Chaque script est **idempotent** — on peut le relancer sans dupliquer les objets. Par exemple, avant de créer un scope DHCP, il vérifie s'il existe déjà avec `Get-DhcpServerv4Scope`."

---

### 🟦 PARTIE 7 — Sécurité by design (1:00)

> *Montrer la rigueur de la conception.*

"La sécurité est intégrée à tous les niveaux — pas ajoutée après coup.

**Réseau Cisco :**
- DHCP Snooping → empêche les serveurs DHCP non autorisés
- Dynamic ARP Inspection → protège contre l'ARP spoofing
- ACL `PRE_AUTH_FILTER` → VLAN 99 ne peut pas accéder aux VLANs internes
- SSH v2 uniquement sur les équipements Cisco, Telnet désactivé

**Windows Server :**
- SMB Signing activé → protection contre les attaques de relais
- Pare-feu Windows actif sur tous les profils
- GPO `GPO-SEC-Serveurs` → verrouillage de session, restriction d'accès
- FGPP différenciées → admins avec politique plus stricte que étudiants

**Linux / Docker :**
- UFW : seul le VLAN 50 Management peut accéder aux services
- Docker networks segmentés : `frontend`, `backend`, `monitoring` — les bases de données ne sont pas exposées directement"

---

### 🟦 PARTIE 8 — Démonstration live (1:00)

> *Adapter selon ce qui est accessible. Préparer en avance.*

```powershell
# ── Depuis PowerShell local ──────────────────────────────

# 1. Vérifier les VMs
vagrant status

# 2. Session WinRM sur DC
$cred = New-Object PSCredential("vagrant", (ConvertTo-SecureString "vagrant" -AsPlainText -Force))
$s = New-PSSession -ComputerName 127.0.0.1 -Port 55985 -Credential $cred -Authentication Negotiate
Invoke-Command -Session $s -ScriptBlock {
    "=== Domaine ==="
    (Get-ADDomain).Forest
    "=== Services ==="
    Get-Service ADWS,DNS,DHCPServer,IAS | Select Name,Status | Format-Table
    "=== DHCP Scopes ==="
    Get-DhcpServerv4Scope | Select Name,State | Format-Table
    "=== NPS Clients ==="
    netsh nps show client 2>&1 | Select-String "Name|Address|State"
}

# 3. Tester Linux
vagrant ssh srv-linux -- -t "docker ps --format 'table {{.Names}}\t{{.Status}}'; exit"
```

**URLs à ouvrir dans le navigateur :**
- GLPI → http://192.168.50.20:8082
- Grafana → http://192.168.50.20:3000
- Prometheus → http://192.168.50.20:9090

---

### 🟦 PARTIE 9 — Bilan et compétences acquises (0:30)

> *Terminer avec du recul professionnel.*

"Ce projet m'a permis de travailler sur des compétences que je n'avais pas avant :
- La configuration 802.1X de bout en bout — du switch Cisco jusqu'à NPS
- L'automatisation d'infrastructure Windows par PowerShell
- La résolution de problèmes complexes — comme l'autorisation DHCP dans l'AD qui nécessitait Enterprise Admin et un token Kerberos frais
- L'orchestration Docker pour des services de production

En termes de bloc de compétences E5 : c'est une réalisation qui couvre la **conception**, le **déploiement**, la **sécurisation** et la **documentation** d'une infrastructure réseau complète."

---

## ❓ Questions probables — Réponses détaillées

---

### Q1 — "Expliquez précisément comment fonctionne le 802.1X"

**Réponse complète :**
> "802.1X est un protocole d'accès réseau basé sur les ports. Il implique 3 acteurs : le **Supplicant** (le PC client qui veut se connecter), l'**Authenticator** (le switch ou AP Cisco, qui contrôle l'accès), et l'**Authentication Server** (NPS sur le DC).
>
> Quand le PC branche, le switch bloque tout le trafic sauf EAP. Il envoie un EAP-Request. Le PC répond avec son identité. Le switch encapsule ça en RADIUS et l'envoie au NPS. NPS vérifie dans AD — si le compte existe et que le mot de passe est correct, il cherche une politique réseau qui correspond au groupe de l'utilisateur. Il répond Access-Accept avec les attributs VLAN. Le switch débloque le port dans le VLAN approprié. Le PC reçoit alors une IP DHCP du bon scope."

---

### Q2 — "Pourquoi avoir choisi NPS plutôt que FreeRADIUS ?"

> "Trois raisons. D'abord l'**intégration native** : NPS est un rôle Windows Server, pas besoin d'installer un service tiers — il s'enregistre directement dans l'AD avec `netsh nps add registeredserver`. Ensuite la **gestion** : les politiques réseau se configurent en GUI ou netsh, et tous les logs d'authentification apparaissent dans l'Observateur d'événements Windows — très pratique pour le dépannage. Enfin la **cohérence** : tout reste dans l'écosystème Microsoft, plus simple à maintenir pour un établissement scolaire sans expert Linux dédié."

---

### Q3 — "C'est quoi concrètement le VLAN 99 ?"

> "C'est le VLAN de quarantaine. Tout appareil qui ne peut pas s'authentifier en 802.1X — soit parce qu'il n'a pas de compte AD, soit parce qu'il ne supporte pas 802.1X — atterrit dans le VLAN 99, réseau 192.168.99.0/24. Il reçoit une IP DHCP, mais une ACL Cisco `PRE_AUTH_FILTER` bloque tout accès aux VLANs internes 10, 20, 30, 40, 50. Il peut seulement atteindre Internet. Ça implémente le principe NAC — Network Access Control — sans agent logiciel sur le poste."

---

### Q4 — "Quel problème avez-vous rencontré ? Comment l'avez-vous résolu ?"

> "Le plus significatif : la commande `Add-DhcpServerInDC` échouait avec 'Failed to initialize directory service resources'. Après investigation, j'ai trouvé deux causes simultanées : premièrement, le conteneur `CN=DhcpRoot` n'est **pas créé automatiquement** lors de la promotion AD — c'est `Add-DhcpServerInDC` lui-même qui doit le créer. Deuxièmement, le compte vagrant utilisé pour le provisioning n'était que dans `Builtin\Administrators`, pas dans `Enterprise Admins` — et la création de ce conteneur dans la partition de Configuration AD nécessite Enterprise Admin.
>
> Solution : j'ai ajouté vagrant à Enterprise Admins via `Add-ADGroupMember`, puis ouvert une **nouvelle** session WinRM pour forcer l'obtention d'un nouveau token Kerberos avec les droits mis à jour — le premier token ne reflétait pas le changement de groupe. Après ça, `Add-DhcpServerInDC` a créé le conteneur et s'est exécuté avec succès."

---

### Q5 — "À quoi servent les Fine-Grained Password Policies ?"

> "Normalement dans un domaine AD, il n'y a qu'une seule politique de mots de passe pour tous les utilisateurs. Les FGPP permettent de définir des règles différentes par groupe ou utilisateur. Dans notre cas, j'ai deux FGPP : `FGPP-Etudiants` appliquée aux groupes étudiants — 8 caractères minimum, expiration 90 jours, blocage après 5 tentatives. Et `FGPP-Admins` appliquée à GRP_IT_Admin et Domain Admins — 12 caractères, expiration 60 jours, blocage après 3 tentatives. C'est le principe de moindre privilège appliqué aux mots de passe."

---

### Q6 — "Qu'est-ce que Grafana surveille concrètement ?"

> "Grafana se connecte à Prometheus qui collecte les métriques via deux exporters. **Node Exporter** expose les métriques de l'OS Ubuntu : CPU, RAM, disque, réseau — en temps réel. **CAdvisor** expose les métriques de chaque conteneur Docker individuellement : combien de CPU utilise GLPI, quelle est la RAM de Nextcloud. Grafana affiche tout ça en dashboards. On peut configurer des alertes — si un conteneur consomme plus de 80% de RAM, une notification part. C'est la supervision sans agent sur les services applicatifs."

---

### Q7 — "Pourquoi Docker et pas des VMs séparées pour chaque service ?"

> "Trois avantages concrets. La **légèreté** : 9 services sur 2 Go de RAM avec Docker, contre 9 VMs qui nécessiteraient 18+ Go. La **portabilité** : un `docker-compose.yml` décrit toute l'infrastructure applicative — on peut la redéployer sur n'importe quel serveur Linux en une commande. La **isolation** : les conteneurs GLPI et Nextcloud ne se voient pas — ils communiquent via des Docker networks dédiés, les bases de données sont dans un réseau `internal:true` non exposé à l'extérieur."

---

### Q8 — "Comment les services Docker survivent à un redémarrage ?"

> "Deux mécanismes. D'abord `restart: unless-stopped` dans le docker-compose — chaque conteneur redémarre automatiquement si le serveur reboot, sauf s'il a été arrêté manuellement. Ensuite les volumes persistants dans `/opt/iris/` — toutes les données de GLPI, Nextcloud, Grafana, Prometheus sont sur le disque de la VM, pas dans le conteneur. Même si on supprime et recrée le conteneur, les données restent."

---

### Q9 — "Comment vous avez géré la sécurité des mots de passe dans vos scripts ?"

> "C'est une bonne question. Dans les scripts PowerShell, les mots de passe sont en clair — c'est un compromis acceptable en environnement lab, mais en production on utiliserait un gestionnaire de secrets comme Azure Key Vault ou HashiCorp Vault. Pour le fichier `.env` de Docker qui contient tous les mots de passe des services Linux, il est dans le `.gitignore` — il ne sera jamais commité dans Git. C'est la pratique minimale pour ne pas exposer des credentials dans un dépôt."

---

### Q10 — "Quelle est la différence entre un GPO et une FGPP ?"

> "Un GPO — Group Policy Object — s'applique à des OUs et peut configurer des centaines de paramètres : verrouillage de l'écran, blocage du panneau de configuration, configuration du pare-feu, etc. La politique de mots de passe dans un GPO est unique au niveau du domaine — elle s'applique à tous. Une FGPP — Fine-Grained Password Policy — s'applique directement à des groupes ou utilisateurs AD et ne gère que les paramètres de mots de passe : longueur, complexité, expiration, historique, seuil de blocage. Les deux sont complémentaires : le GPO gère le comportement des postes, la FGPP gère la politique de sécurité des comptes par profil."

---

## 📊 Chiffres clés — À réciter sans hésiter

| Indicateur | Valeur |
|------------|--------|
| VLANs configurés | **6** (10, 20, 30, 40, 50, 99) |
| Scopes DHCP actifs | **6** |
| Comptes AD créés | **26** (+2 comptes service) |
| OUs Active Directory | **17** |
| Groupes AD | **6** |
| Scripts PowerShell | **6** (automatisation complète) |
| Clients RADIUS | **3** (AP, Switch, Routeur) |
| Politiques NPS | **6** (une par VLAN) |
| Services Docker | **9** |
| GPO de sécurité | **4** |
| FGPP | **2** |
| Tests validés en lab | **22 / 53** |
| Ping DC ↔ Linux | **< 2 ms** |
| Documents produits | **7** |

---

## ✅ Checklist avant la présentation

### La veille
- [ ] Relire ce document entièrement une fois
- [ ] Relire `06_Credentials_Access_RP01.md` pour avoir les mots de passe en tête
- [ ] Faire une répétition complète à voix haute, chronomètre en main

### Le matin
- [ ] Lancer `vagrant up` — laisser les VMs démarrer (~5 minutes)
- [ ] Vérifier `vagrant status` → `dc-iris: running` + `srv-linux: running`
- [ ] Tester WinRM : `Test-NetConnection 127.0.0.1 -Port 55985`
- [ ] Ouvrir dans le navigateur : http://192.168.50.20:8082 (GLPI) — vérifier HTTP 200
- [ ] Ouvrir dans le navigateur : http://192.168.50.20:3000 (Grafana) — vérifier login
- [ ] Avoir ce fichier ouvert en plein écran (ou imprimé)
- [ ] Avoir le schéma réseau prêt à montrer

### Pendant la présentation
- [ ] Parler lentement sur la partie 802.1X — c'est la plus technique
- [ ] Pointer les éléments sur le schéma quand tu l'expliques
- [ ] Si une démo plante → "Je vous montre le résultat via la commande PowerShell"
- [ ] Terminer par "Je suis prêt à approfondir n'importe quel point"

---

*Nedjmeddine Belloum — BTS SIO SISR — MEDIASCHOOL Nice — Épreuve E5 2026*
