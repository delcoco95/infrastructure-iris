# 16 — WiFi Multi-SSID VLAN Option A — AP2-IRIS (EWC C9105AXI-E)
**Projet :** IRIS-NICE-2024-RP01  
**Date :** Avril 2026  
**Auteur :** Nedjmeddine Belloum  
**Équipement :** AP2-IRIS — Cisco C9105AXI-E EWC — 192.168.50.5

---

## 1. Contexte et problème initial

### Infrastructure WiFi cible
L'appel d'offre IRIS-NICE-2026-RP01 demandait une authentification 802.1X WPA2-Enterprise avec attribution dynamique des VLANs selon le profil AD de l'utilisateur (identique au câblé via SW2-IRIS).

### Limitation découverte : EWC 17.9.8.5 + aaa-override + FlexConnect

L'approche initiale (Option B) utilisait un seul SSID avec `aaa-override` pour laisser NPS envoyer le `Tunnel-Pvt-Group-ID` et l'EWC placer le client dans le bon VLAN dynamiquement.

**Résultat : échec systématique — "VLAN failure" lors de la tentative de placement dans le VLAN dynamique.**

Diagnostic :
- EWC IOS-XE 17.9.8.5 en mode **FlexConnect local switching** est incompatible avec `aaa-override` + attribution VLAN dynamique via RADIUS Tunnel attributes
- Le VLAN override fonctionne uniquement en mode **central switching** (Local mode, non FlexConnect)
- Contournement impossible sans changer le mode AP (ce qui modifierait l'architecture réseau)

**Décision : abandon de l'Option B, mise en place de l'Option A.**

---

## 2. Solution retenue : Option A — Multi-SSID, VLAN statique par policy

### Principe
- **4 SSIDs dédiés**, un par profil utilisateur
- Chaque SSID est lié à une **policy** qui définit le VLAN statiquement
- NPS authentifie l'utilisateur (PEAP/MSCHAPv2 via AD) mais **n'envoie pas** d'attributs Tunnel-Pvt-Group-ID
- Le VLAN est déterminé par le SSID auquel l'utilisateur se connecte, pas par son profil RADIUS

### Tableau des SSIDs

| SSID | WLAN ID | Policy AP | VLAN | Profil concerné |
|------|---------|-----------|------|-----------------|
| IRIS-WIFI | 1 | POLICY-ETUDIANTS | 10 | Étudiants SISR + SLAM |
| IRIS-PROFS | 2 | POLICY-PROFS | 20 | Professeurs |
| IRIS-ADMIN | 3 | POLICY-ADMIN | 30 | Administration |
| IRIS-GUEST | 4 | POLICY-INVITES | 40 | Invités / Visiteurs |

### Avantages de l'Option A
- Compatible EWC 17.9.x en mode FlexConnect local switching
- Configuration simple et prévisible — pas de dépendance aux attributs RADIUS
- Testable facilement (on choisit son SSID explicitement)
- NPS reste le gardien de l'authentification (access-accept ou access-reject)

### Limites
- Un utilisateur peut choisir un SSID qui ne correspond pas à son profil (ex: étudiant sur IRIS-PROFS)
- Mitigé partiellement par les ACL inter-VLAN sur RT2-IRIS

---

## 3. Configuration AP2-IRIS (EWC IOS-XE 17.9)

### 3.1 RADIUS server group

```
radius server NPS-DC-IRIS
 address ipv4 192.168.50.10 auth-port 1812 acct-port 1813
 key RadiusAP_IRIS_2026!

aaa group server radius NPS-DC-IRIS-GROUP
 server name NPS-DC-IRIS
```

### 3.2 AAA configuration

```
aaa new-model
aaa authentication dot1x DOT1X-IRIS group NPS-DC-IRIS-GROUP
aaa authorization network DOT1X-IRIS group NPS-DC-IRIS-GROUP
aaa accounting dot1x default start-stop group NPS-DC-IRIS-GROUP
```

### 3.3 WLANs (4 SSIDs)

```
wlan IRIS-WIFI 1 IRIS-WIFI
 security wpa psk
 security wpa akm dot1x
 security dot1x authentication-list DOT1X-IRIS
 no shutdown

wlan IRIS-PROFS 2 IRIS-PROFS
 security wpa psk
 security wpa akm dot1x
 security dot1x authentication-list DOT1X-IRIS
 no shutdown

wlan IRIS-ADMIN 3 IRIS-ADMIN
 security wpa psk
 security wpa akm dot1x
 security dot1x authentication-list DOT1X-IRIS
 no shutdown

wlan IRIS-GUEST 4 IRIS-GUEST
 security wpa psk
 security wpa akm dot1x
 security dot1x authentication-list DOT1X-IRIS
 no shutdown
```

### 3.4 Policies AP (VLAN statique)

```
wireless profile policy POLICY-ETUDIANTS
 vlan 10
 no central switching
 no central dhcp
 no shutdown

wireless profile policy POLICY-PROFS
 vlan 20
 no central switching
 no central dhcp
 no shutdown

wireless profile policy POLICY-ADMIN
 vlan 30
 no central switching
 no central dhcp
 no shutdown

wireless profile policy POLICY-INVITES
 vlan 40
 no central switching
 no central dhcp
 no shutdown
```

### 3.5 Policy Tag

```
wireless tag policy PTAG-IRIS
 wlan IRIS-WIFI policy POLICY-ETUDIANTS
 wlan IRIS-PROFS policy POLICY-PROFS
 wlan IRIS-ADMIN policy POLICY-ADMIN
 wlan IRIS-GUEST policy POLICY-INVITES
```

### 3.6 Application du Policy Tag sur l'AP

```
ap 802.1x-supplicant-profile default-ap-profile
!
ap tag-persistent
ap 192.168.50.5
 policy-tag PTAG-IRIS
 site-tag default-site-tag
 rf-tag default-rf-tag
```

### 3.7 Flex profile

```
wireless profile flex default-flex-profile
 native-vlan-id 50
 vlan-name VLAN10 vlan-id 10
 vlan-name VLAN20 vlan-id 20
 vlan-name VLAN30 vlan-id 30
 vlan-name VLAN40 vlan-id 40
 vlan-name MGMT  vlan-id 50
```

---

## 4. Configuration NPS côté DC-IRIS-01

### Politiques réseau (état final)

| Politique | Ordre | Conditions | Résultat |
|-----------|-------|------------|---------|
| CRP_EAP_8021X | — | Toutes connexions 802.1X entrant | Forward local NPS |
| NP_Etudiants | 1 | Groupes : GRP_Etudiants_SISR + GRP_Etudiants_SLAM, NAS-Port-Type = 19 | Access-ACCEPT |
| NP_Profs | 2 | Groupe : GRP_Profs | Access-ACCEPT |
| NP_Admin | 3 | Groupe : GRP_Administration | Access-ACCEPT |
| NP_Guest | 4 | Groupe : GRP_Invites | Access-ACCEPT |

> **Important :** Les politiques NPS n'incluent PAS d'attributs Tunnel-Pvt-Group-ID.  
> L'attribution VLAN se fait uniquement via la policy AP (statique par SSID).

### Commande de vérification NPS

```powershell
netsh nps show np
# Doit afficher les 4 politiques réseau dans l'ordre

netsh nps show client
# Doit afficher : AP2-IRIS (192.168.50.5), SW2-IRIS, RT2-IRIS
```

---

## 5. Commandes de vérification AP2-IRIS

```
# État des WLANs
show wlan summary

# État des policies
show wireless profile policy summary

# Policy tag
show wireless tag policy

# Clients connectés
show wireless client summary

# Authentifications RADIUS en cours
debug radius authentication

# Vérifier flex profile
show wireless profile flex summary

# État de l'AP
show ap config general
show ap status
```

---

## 6. Tests réalisés et résultats

### Protocole de test

| Test | SSID | Compte AD | Groupe | VLAN attendu | Résultat |
|------|------|-----------|--------|--------------|---------|
| T-01 | IRIS-WIFI | nedj.belloum | GRP_Etudiants_SISR | 10 | ✅ VLAN 10 |
| T-02 | IRIS-WIFI | yanis.adidi | GRP_Etudiants_SLAM | 10 | ✅ VLAN 10 |
| T-03 | IRIS-PROFS | yan.bourquard | GRP_Profs | 20 | ✅ VLAN 20 |
| T-04 | IRIS-ADMIN | marie.agnamazian | GRP_Administration | 30 | ✅ VLAN 30 |
| T-05 | IRIS-GUEST | invite.test | GRP_Invites | 40 | ✅ VLAN 40 |
| T-06 | IRIS-WIFI | compte_inexistant | — | Rejet | ✅ Access-REJECT |
| T-07 | IRIS-PROFS | nedj.belloum | GRP_Etudiants_SISR | 20 (SSID) | ✅ VLAN 20 (statique) |

> **Note sur T-07 :** Un étudiant sur IRIS-PROFS obtient bien le VLAN 20 — NPS autorise car il n'y a pas de condition de groupe sur le SSID. C'est la limite connue de l'Option A.

### Validation DHCP

Chaque VLAN distribue correctement des IPs depuis les scopes DC-IRIS-01 :
- VLAN 10 → 192.168.10.31-254 (gateway 192.168.10.1)
- VLAN 20 → 192.168.20.31-254 (gateway 192.168.20.1)
- VLAN 30 → 192.168.30.31-254 (gateway 192.168.30.1)
- VLAN 40 → 192.168.40.31-254 (gateway 192.168.40.1)

---

## 7. Références

- Cisco EWC Configuration Guide IOS-XE 17.9 — Wireless FlexConnect
- Cisco Bug ID : FlexConnect + aaa-override VLAN assignment limitation
- RFC 3580 — IEEE 802.1X RADIUS Usage Guidelines (VLAN via Tunnel Attributes)
- NPS documentation Microsoft — Network Policy configuration

---

*Nedjmeddine Belloum — BTS SIO SISR — MEDIASCHOOL Nice — Avril 2026*
