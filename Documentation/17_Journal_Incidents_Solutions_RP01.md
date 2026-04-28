# 17 — Journal des Incidents et Solutions — RP-01 IRIS Nice
## Retour d'expérience technique complet

**Projet :** IRIS-NICE-2024-RP01  
**Auteur :** Nedjmeddine Belloum — BTS SIO SISR  
**Établissement :** MEDIASCHOOL Nice  
**Période :** Novembre 2025 – Avril 2026  

> Ce document recense toutes les difficultés rencontrées lors du déploiement de l'infrastructure RP-01, les diagnostics effectués et les solutions appliquées. Il constitue un retour d'expérience honnête et pédagogique.

---

## Incident #1 — NAT manquant sur VLAN 50 → DC sans Internet

### Contexte
Après installation de Windows Server 2022 sur DC-IRIS-01 (VLAN 50, IP 192.168.50.10), la VM ne pouvait pas accéder à Internet. Les rôles Windows Server nécessitent une connexion pour l'activation et les mises à jour.

### Symptômes
```
ping 8.8.8.8 depuis DC-IRIS-01 → Request timed out
Install-WindowsFeature → téléchargement impossible
```

### Diagnostic
Sur RT2-IRIS, la liste d'accès NAT ne couvrait que les anciens VLANs (héritage configuration Linux) :
```
ip access-list extended NAT_LIST
 permit ip 192.168.10.0 0.0.0.255 any   ← VLAN Étudiants OK
 permit ip 192.168.20.0 0.0.0.255 any   ← VLAN Profs OK
 ...
 ! 192.168.50.0/24 = ABSENT !
```
Le VLAN 50 (Management IT) n'était pas inclus dans la règle NAT car dans l'ancienne infra Linux, le Management était sur VLAN 99.

### Solution appliquée
```
RT2-IRIS(config)# ip access-list extended NAT_LIST
RT2-IRIS(config-ext-nacl)# permit ip 192.168.50.0 0.0.0.255 any
RT2-IRIS(config)# end
RT2-IRIS# write memory
```

### Leçon retenue
Lors d'une migration de numérotation VLAN, **toujours auditer toutes les ACL qui référencent les anciens numéros**. La règle NAT est silencieuse — elle ne génère aucune erreur si un réseau est absent, elle ignore simplement les paquets.

---

## Incident #2 — Autorisation DHCP refusée (Enterprise Admins)

### Contexte
Le script `03_configure_dhcp.ps1` tentait d'autoriser le serveur DHCP dans l'Active Directory via `Add-DhcpServerInDC`, ce qui est nécessaire en domaine AD pour éviter les serveurs DHCP non autorisés.

### Symptômes
```
Add-DhcpServerInDC : Failed to initialize AD resources.
Access denied.
```

### Diagnostic
L'opération `Add-DhcpServerInDC` requiert l'appartenance au groupe **Enterprise Admins** d'Active Directory. Le compte utilisé lors du provisioning Vagrant n'appartenait pas à ce groupe.

### Solution appliquée
```powershell
Add-ADGroupMember -Identity "Enterprise Admins" -Members "vagrant"
# Puis relancer
Add-DhcpServerInDC -DnsName "dc-iris-01.mediaschool.local" -IPAddress 192.168.50.10
```

### Leçon retenue
Les droits **Domain Admins** ne suffisent pas pour toutes les opérations AD. Certaines (autorisation DHCP, modification du schéma, réplication multi-sites) nécessitent **Enterprise Admins**. En environnement de déploiement automatisé, le compte de service doit avoir les droits requis dès le départ.

---

## Incident #3 — Syntaxe `netsh nps` incorrecte (NPS automation)

### Contexte
La configuration de NPS via PowerShell (module `Nps`) s'est révélée incompatible avec Windows Server 2022. Plusieurs cmdlets avaient des paramètres qui n'existaient pas ou qui se comportaient différemment.

### Symptôme 1 — `New-NpsRadiusClient` parameter invalide
```powershell
New-NpsRadiusClient -Enabled $True -Name "AP-IRIS" ...
# Erreur : A parameter cannot be found that matches parameter name 'Enabled'
```
Le paramètre `-Enabled` n'existe pas dans le module NPS de Server 2022.

### Solution 1
Remplacement complet du module PS par `netsh nps` :
```
netsh nps add client name="AP-IRIS" address=192.168.50.5 sharedsecret=RadiusAP_IRIS_2026!
```

### Symptôme 2 — `netsh nps add registeredserver` retourne "Element not found"
```
netsh nps add registeredserver domain=mediaschool.local server=DC-IRIS-01
# Résultat : Element not found.
```

### Solution 2
La syntaxe avec arguments explicites était incorrecte. La commande sans arguments fonctionne car elle enregistre le serveur local automatiquement :
```
netsh nps add registeredserver
```

### Leçon retenue
Les **modules PowerShell NPS** ne sont pas fiables entre versions de Windows Server. Préférer `netsh nps` pour les scripts de déploiement NPS — plus stable et documenté dans les guides Microsoft officiels.

---

## Incident #4 — PEAP : certificat auto-signé refusé par Windows 11

### Contexte
Lors des premiers tests 802.1X depuis un poste Windows 11, la connexion échouait immédiatement avec un message "Impossible de se connecter à ce réseau".

### Symptômes
- Aucun log 6272 ou 6273 dans NPS Event Viewer (le serveur RADIUS n'était même pas contacté)
- Message Windows 11 : "Impossible de se connecter"

### Diagnostic
Windows 11 **valide le certificat du serveur RADIUS** par défaut. Le certificat auto-signé du DC-IRIS-01 n'était pas dans les CA de confiance du poste client.

### Solution appliquée
Dans le profil WiFi Windows 11 → Paramètres avancés 802.1X :
- Décocher "Valider le certificat du serveur" (mode lab)
- Ou : déployer le certificat DC-IRIS-01 via GPO dans les CA de confiance (mode production)

### Leçon retenue
En **production**, déployer un certificat PKI via AD CS + GPO auto-enrôlement. En **lab**, désactiver temporairement la validation du certificat côté client. Ne jamais oublier ce paramètre lors des tests — c'est la cause #1 des échecs 802.1X silencieux.

---

## Incident #5 — EWC 17.9 : `aaa-override` incompatible FlexConnect (obstacle majeur)

### Contexte
La conception initiale du WiFi (Option B) prévoyait un seul SSID `IRIS-WIFI` avec attribution dynamique du VLAN via NPS (attribut `Tunnel-Pvt-Group-ID`). La policy AP avait `aaa-override` activé pour permettre à NPS de pousser le VLAN au moment de l'authentification.

### Symptômes
```
AP2-IRIS# show wireless client detail mac 129b.9bd7.7a89
  Current State : Exclusion
  Exclusion Reason: VLAN failure
```
Le client s'authentifiait correctement auprès de NPS (log 6272 visible) mais était immédiatement exclu avec le motif "VLAN failure".

### Diagnostic approfondi
Après analyse des logs AP et recherche documentaire :
- Le Cisco C9105AXI-E fonctionne en mode **EWC (Embedded Wireless Controller)** avec **FlexConnect local switching**
- En mode FlexConnect local switching, **EWC IOS-XE 17.9.x ne supporte pas** `aaa-override` + attribution VLAN dynamique via attributs Tunnel RADIUS
- Cette fonctionnalité n'est disponible qu'en mode **central switching** (Local mode), incompatible avec l'architecture réseau physique déployée

### Tentatives échouées avant la solution
1. `aaa-override` ON → toujours "VLAN failure"
2. `central switching` ON → erreur "not supported on EWC"
3. `central dhcp` ON → erreur identique
4. Mise à jour firmware (EWC 17.9.8.5) → problème non résolu

### Solution retenue : Option A — Multi-SSID VLAN statique
Abandon de l'Option B. Création de **4 SSIDs dédiés**, chacun lié à une policy avec un VLAN statique :

| SSID | Policy | VLAN | Profil |
|------|--------|------|--------|
| IRIS-WIFI | POLICY-ETUDIANTS | 10 | Étudiants |
| IRIS-PROFS | POLICY-PROFS | 20 | Professeurs |
| IRIS-ADMIN | POLICY-ADMIN | 30 | Administration |
| IRIS-GUEST | POLICY-INVITES | 40 | Invités |

NPS continue d'authentifier les utilisateurs (accept/reject) mais ne pousse plus d'attributs VLAN. La séparation des profils se fait par le choix du SSID.

### Leçon retenue
**Avant de concevoir une solution WiFi d'entreprise, vérifier la compatibilité exacte entre :**
- Le mode de fonctionnement de l'AP (FlexConnect / Local / WLC centralisé)
- La version firmware EWC/WLC
- Les fonctionnalités 802.1X souhaitées

La documentation Cisco mentionne cette limitation dans les notes de version EWC 17.9 mais ce n'est pas évident à trouver. Le mode FlexConnect est conçu pour les sites distants sans WLC central — il a des limitations inhérentes sur l'assignation dynamique de VLAN.

---

## Incident #6 — `aaa-override` encore actif sur POLICY-PROFS et POLICY-ADMIN

### Contexte
Après la mise en place de l'Option A (4 SSIDs), les connexions sur IRIS-PROFS et IRIS-ADMIN continuaient d'échouer alors qu'IRIS-WIFI fonctionnait.

### Symptômes
```
AP2-IRIS# show wireless client summary
! Clients sur IRIS-PROFS et IRIS-ADMIN : absents
! Seul IRIS-WIFI a des clients
```

### Diagnostic
```
AP2-IRIS# show wireless profile policy detail POLICY-PROFS
  AAA Override    : ENABLED   ← le problème !
```
Les nouvelles policies (POLICY-PROFS, POLICY-ADMIN) avaient `aaa-override` activé par défaut. Seule POLICY-INVITES l'avait désactivé correctement.

### Solution appliquée
```
AP2-IRIS(config)# wireless profile policy POLICY-PROFS
AP2-IRIS(config-wireless-policy)# shutdown
AP2-IRIS(config-wireless-policy)# no aaa-override
AP2-IRIS(config-wireless-policy)# no shutdown
AP2-IRIS(config-wireless-policy)# exit
AP2-IRIS(config)# wireless profile policy POLICY-ADMIN
AP2-IRIS(config-wireless-policy)# shutdown
AP2-IRIS(config-wireless-policy)# no aaa-override
AP2-IRIS(config-wireless-policy)# no shutdown
```

### Leçon retenue
Sur EWC, `aaa-override` est **activé par défaut** sur les nouvelles policy profiles. Il faut systématiquement vérifier ce paramètre après chaque création de policy. La commande `show wireless profile policy detail <nom>` doit afficher `AAA Override : DISABLED` pour une policy Option A.

---

## Incident #7 — Mauvaise `authentication-list` sur les nouveaux WLANs

### Contexte
Après avoir désactivé `aaa-override`, les connexions sur IRIS-PROFS restaient impossibles. Le téléphone de test semblait tenter la connexion mais ne recevait aucune réponse RADIUS.

### Symptômes
- Aucun événement NPS (6272/6273) dans Event Viewer lors des tentatives sur IRIS-PROFS
- `show wireless client summary` vide pour IRIS-PROFS

### Diagnostic
```
AP2-IRIS# show running-config | include authentication-list
 security dot1x authentication-list DOT1X-IRIS    ← IRIS-WIFI (OK)
 security dot1x authentication-list RADIUS-DOT1X  ← IRIS-PROFS (FAUX !)
 security dot1x authentication-list RADIUS-DOT1X  ← IRIS-ADMIN (FAUX !)
 security dot1x authentication-list RADIUS-DOT1X  ← IRIS-GUEST (FAUX !)
```

Les nouveaux WLANs utilisaient `RADIUS-DOT1X` comme authentication-list, mais **cette liste n'existe pas** sur cet AP. La seule liste AAA valide est `DOT1X-IRIS`. Les WLANs envoyaient les requêtes d'authentification dans le vide.

### Solution appliquée
Désactivation préalable obligatoire de chaque WLAN (le changement de `authentication-list` est impossible sur un WLAN actif) :

```
AP2-IRIS(config)# wlan IRIS-PROFS 2 IRIS-PROFS
AP2-IRIS(config-wlan)# shutdown
AP2-IRIS(config-wlan)# security dot1x authentication-list DOT1X-IRIS
AP2-IRIS(config-wlan)# no shutdown
! Répété pour IRIS-ADMIN et IRIS-GUEST
```

### Leçon retenue
Sur EWC, quand on crée un WLAN en spécifiant une `authentication-list`, **le nom doit correspondre exactement** à une liste AAA existante sur l'AP. Si la liste n'existe pas, aucune erreur n'est levée — le WLAN est créé mais silencieusement dysfonctionnel. Toujours vérifier avec :
```
show aaa method-lists authentication | include dot1x
```

---

## Incident #8 — Modification WLAN refusée sans `shutdown` préalable

### Contexte
Lors de la tentative de correction de l'authentication-list (incident #7), la commande échouait :

### Symptôme
```
AP2-IRIS(config-wlan)# security dot1x authentication-list DOT1X-IRIS
% WLAN needs to be disabled before performing this operation.
```

### Explication
Sur EWC, **toute modification de la sécurité d'un WLAN actif est bloquée**. Le WLAN doit être mis en `shutdown` avant tout changement, puis remis en `no shutdown` après.

### Solution standard (à appliquer systématiquement)
```
wlan <nom> <id> <ssid>
  shutdown
  <modification>
  no shutdown
```

### Leçon retenue
Sur EWC IOS-XE, le pattern `shutdown → modification → no shutdown` est **obligatoire** pour les changements de sécurité sur un WLAN. De même, les policy profiles nécessitent `shutdown` avant modification. C'est différent d'un WLC Catalyst Center où certains changements s'appliquent à chaud.

---

## Incident #9 — Scopes DHCP VLAN 50 et 99 manquants après provisioning

### Contexte
Après exécution du script `03_configure_dhcp.ps1`, les scopes VLAN 10/20/30/40 étaient présents mais VLAN 50 et 99 étaient absents.

### Symptôme
```powershell
Get-DhcpServerv4Scope | Select ScopeId, Name
# ScopeId         Name
# --------        ----
# 192.168.10.0    VLAN10-ETUDIANTS
# 192.168.20.0    VLAN20-PROFS
# 192.168.30.0    VLAN30-ADMIN
# 192.168.40.0    VLAN40-GUEST
# ! VLAN50 et VLAN99 absents
```

### Diagnostic
Le script PowerShell avait un comportement "fail-fast" : une erreur dans la création d'un scope stoppait l'exécution des suivants. L'erreur sur `Add-DhcpServerInDC` (incident #2) avait tronqué l'exécution avant la création des scopes VLAN 50 et 99.

### Solution appliquée
Ajout de vérifications d'existence et de `try/catch` dans le script, puis ré-exécution partielle :

```powershell
# Vérifier si scope existe avant création
if (!(Get-DhcpServerv4Scope -ScopeId "192.168.50.0" -ErrorAction SilentlyContinue)) {
    Add-DhcpServerv4Scope -Name "VLAN50-MANAGEMENT" -StartRange 192.168.50.50 `
        -EndRange 192.168.50.254 -SubnetMask 255.255.255.0 -State Active
}
```

### Leçon retenue
Les scripts de provisioning d'infrastructure doivent être **idempotents** : exécutables plusieurs fois sans erreur, avec vérification d'existence avant création. Un script qui s'arrête à mi-chemin sans idempotence laisse l'infrastructure dans un état incohérent difficile à diagnostiquer.

---

## Incident #10 — Fichiers firmware Cisco dans l'historique Git (push bloqué)

### Contexte
Lors du premier `git push origin main` après la refonte documentaire complète, GitHub a refusé le push.

### Symptôme
```
remote: error: File cisco/configs-cisco/TFTP/C9800-AP-iosxe-wlc.bin is 289.00 MB
remote: error: GH001: Large files detected. You may want to try Git Large File Storage
! [remote rejected] main -> main (pre-receive hook declined)
error: failed to push some refs to 'https://github.com/...'
```

Le fichier firmware `C9800-AP-iosxe-wlc.bin` (289 MB) avait été commité dans l'historique local — il dépassait la limite GitHub de 100 MB.

### Diagnostic
```powershell
git log --oneline
# 908d1c9 (HEAD) docs: refonte documentation...
# d1a7cf3 (origin/main) previous commit

git show --stat 908d1c9 | Select-String "TFTP"
# create mode 100644 cisco/configs-cisco/TFTP/C9800-AP-iosxe-wlc.bin
```
Le commit `908d1c9` contenait les fichiers firmware. Ce commit n'avait jamais été pushé vers GitHub (origin/main était à `d1a7cf3`).

### Solution appliquée
Ré-écriture de l'historique local (safe car le commit n'était pas encore sur GitHub) :

```powershell
# Soft reset : revenir à origin/main en conservant tous les fichiers en staging
git reset --soft d1a7cf3

# Ajouter TFTP/ au .gitignore
echo "cisco/configs-cisco/TFTP/" >> .gitignore

# Re-stager tout SAUF le dossier TFTP
git add .gitignore Documentation/ cisco/backups/ cisco/configs-cisco/ scripts/ ...
# (git respecte .gitignore, TFTP/ est ignoré automatiquement)

# Nouveau commit propre
git commit -m "docs: refonte documentation RP01 + WiFi Option A..."

# Push réussi
git push origin main
```

### Leçon retenue
**Avant tout commit, vérifier la taille des fichiers** avec :
```powershell
git diff --cached --stat | Where-Object { $_ -match "Bin" }
```
Les fichiers de firmware, ISO, dumps de VM n'ont pas leur place dans Git. Utiliser `.gitignore` **dès le début du projet** pour exclure les répertoires qui pourraient contenir de gros fichiers binaires. Pour stocker des fichiers > 100 MB, utiliser Git LFS ou un stockage externe (S3, NAS, etc.).

---

## Incident #11 — ClamAV redémarre en boucle (ressources insuffisantes)

### Contexte
Dans l'environnement lab Vagrant (VM Ubuntu avec 2 Go RAM), le conteneur ClamAV redémarre en boucle et n'est jamais stable.

### Symptôme
```bash
docker ps
# CONTAINER ID   IMAGE              STATUS
# xxx            clamav/clamav:1.3  Restarting (1) 2 minutes ago
```

### Diagnostic
ClamAV charge sa base de signatures virale en RAM au démarrage. La base ClamAV pèse environ **1,5 à 2 Go en mémoire**. La VM lab dispose seulement de 2 Go de RAM totaux, partagés entre Ubuntu, Docker daemon et les autres conteneurs.

### Solution (lab vs production)
- **Lab :** Comportement accepté, documenté comme avertissement (⚠️). Ne pas inclure ClamAV dans les tests de validation lab.
- **Production :** VM SRV-LINUX-IRIS avec **≥ 4 Go RAM dédiés** (recommandé : 6 Go avec ClamAV actif).

### Leçon retenue
Les **outils de sécurité** (antivirus, IDS) ont souvent des prérequis en ressources non négligeables. Les dimensionner dans le Vagrantfile dès le départ :
```ruby
v.memory = 4096  # 4 Go minimum pour ClamAV
```

---

## Récapitulatif des incidents

| # | Composant | Problème | Criticité | Résolu |
|---|-----------|---------|-----------|--------|
| 1 | RT2-IRIS | NAT VLAN 50 manquant | 🔴 Bloquant | ✅ |
| 2 | DC-IRIS-01 | DHCP authorization Enterprise Admins | 🟠 Important | ✅ |
| 3 | DC-IRIS-01 | NPS cmdlets PS incompatibles Server 2022 | 🟠 Important | ✅ |
| 4 | PC-CLIENT | Certificat RADIUS auto-signé refusé Win11 | 🟠 Important | ✅ |
| 5 | AP2-IRIS | EWC 17.9 aaa-override + FlexConnect incompatible | 🔴 Bloquant majeur | ✅ (Option A) |
| 6 | AP2-IRIS | aaa-override actif sur nouvelles policies | 🟠 Important | ✅ |
| 7 | AP2-IRIS | authentication-list inexistante sur nouveaux WLANs | 🟠 Important | ✅ |
| 8 | AP2-IRIS | Modification WLAN sans shutdown préalable | 🟡 Mineur | ✅ (procédure) |
| 9 | DC-IRIS-01 | Scopes DHCP manquants après erreur script | 🟡 Mineur | ✅ |
| 10 | Git | Firmware Cisco 289 MB dans historique | 🟠 Important | ✅ (soft reset) |
| 11 | SRV-LINUX | ClamAV RAM insuffisante en lab | 🟡 Mineur (lab) | ⚠️ Prod uniquement |

---

*Nedjmeddine Belloum — BTS SIO SISR — MEDIASCHOOL Nice — Avril 2026*
