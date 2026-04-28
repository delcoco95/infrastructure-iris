# Guide Migration SW2-IRIS vers L3 — RP01

**Auteur :** Nedjmeddine Belloum  
**Date :** 25/04/2026  
**Objectif :** Remplacer RT2-IRIS (débranché) par SW2-IRIS en cœur L3

---

## ⚠️ VÉRIFICATION CRITIQUE AVANT TOUT

```cisco
SW2-IRIS# show version | include Software
SW2-IRIS# show sdm prefer
```

| Résultat | Action |
|---------|--------|
| `LAN Base` + `default` ou `lanbase-routing` | ✅ Continuer |
| `LAN Lite` | ❌ STOP — ip routing impossible, plan alternatif requis |

---

## 🐛 Bugs Identifiés dans la Config Actuelle

| # | Bug | Impact | Correction |
|---|-----|--------|------------|
| 1 | `ip dhcp snooping trust` uniquement sur Gi0/1 (débranché) | Toutes les offres DHCP du DC sont **droppées silencieusement** | Ajouter `ip dhcp snooping trust interface FastEthernet0/1` |
| 2 | `ip default-gateway 192.168.50.1` + `ip routing` | Conflit : default-gateway ignoré, pas de route de sortie | Supprimer `ip default-gateway`, documenter perte internet |
| 3 | SVIs VLAN 10/20/30/40/99 absents | Pas de routage inter-VLAN, pas de DHCP relay | Créer les SVIs avec `ip helper-address 192.168.50.10` |
| 4 | Gi0/1 (trunk vers RT2-IRIS) reste up | Port dangling → risque STP/CDP | `shutdown` sur Gi0/1 |
| 5 | Pas d'`auth-fail vlan` sur ports 802.1X | Si RADIUS KO → ports bloqués indéfiniment | Ajouter `authentication event fail action authorize vlan 99` |

---

## 📋 Ordre des Opérations (Séquence Critique)

### PHASE A — Pré-migration (fenêtre de maintenance requise)

```
[1] Sauvegarder la config actuelle
    copy running-config tftp://192.168.50.10/SW2-IRIS-backup.cfg

[2] Vérifier LAN Base
    show version | include Software

[3] Activer SDM routing
    sdm prefer lanbase-routing
    end
    reload    ← ⚠️ INTERRUPTION ~3-5 min
```

### PHASE B — Après reload

```
[4] Confirmer SDM
    show sdm prefer   → doit afficher "lanbase-routing"

[5] Activer ip routing
    ip routing

[6] Supprimer default-gateway L2
    no ip default-gateway 192.168.50.1

[7] Créer les SVIs (Vlan10, 20, 30, 40, 99) avec ip helper-address

[8] Corriger DHCP Snooping trust (Fa0/1 trusted)

[9] Améliorer auth-fail sur ports 802.1X

[10] Shutdown Gi0/1 (RT2-IRIS débranché)
```

### PHASE C — Windows DC (pools DHCP)

```powershell
# Créer les 6 pools DHCP sur DC-IRIS-01 (PowerShell)

# Pool VLAN 10 — Étudiants
Add-DhcpServerv4Scope -Name "VLAN10-Etudiants" `
  -StartRange 192.168.10.31 -EndRange 192.168.10.254 `
  -SubnetMask 255.255.255.0 -State Active
Set-DhcpServerv4OptionValue -ScopeId 192.168.10.0 `
  -Router 192.168.10.1 `
  -DnsServer 192.168.50.10 `
  -OptionId 042 -Value 192.168.50.10   # NTP

# Pool VLAN 20 — Profs
Add-DhcpServerv4Scope -Name "VLAN20-Profs" `
  -StartRange 192.168.20.31 -EndRange 192.168.20.254 `
  -SubnetMask 255.255.255.0 -State Active
Set-DhcpServerv4OptionValue -ScopeId 192.168.20.0 `
  -Router 192.168.20.1 -DnsServer 192.168.50.10

# Pool VLAN 30 — Administration
Add-DhcpServerv4Scope -Name "VLAN30-Administration" `
  -StartRange 192.168.30.31 -EndRange 192.168.30.254 `
  -SubnetMask 255.255.255.0 -State Active
Set-DhcpServerv4OptionValue -ScopeId 192.168.30.0 `
  -Router 192.168.30.1 -DnsServer 192.168.50.10

# Pool VLAN 40 — Guest
Add-DhcpServerv4Scope -Name "VLAN40-Guest" `
  -StartRange 192.168.40.31 -EndRange 192.168.40.254 `
  -SubnetMask 255.255.255.0 -State Active
Set-DhcpServerv4OptionValue -ScopeId 192.168.40.0 `
  -Router 192.168.40.1 -DnsServer 192.168.50.10

# Pool VLAN 99 — PRE_AUTH
Add-DhcpServerv4Scope -Name "VLAN99-PreAuth" `
  -StartRange 192.168.99.31 -EndRange 192.168.99.254 `
  -SubnetMask 255.255.255.0 -State Active
Set-DhcpServerv4OptionValue -ScopeId 192.168.99.0 `
  -Router 192.168.99.1 -DnsServer 192.168.50.10
```

### PHASE D — NPS (RADIUS + VLAN dynamique)

#### Clients RADIUS à déclarer dans NPS :

| Client | IP | Secret |
|--------|-----|--------|
| SW2-IRIS | 192.168.50.2 | RadiusSW_IRIS_2026! |
| AP2-IRIS | 192.168.50.5 | RadiusAP_IRIS_2026! |

#### Politiques réseau NPS (une par groupe AD) :

| Politique | Conditions | Attributs RADIUS |
|-----------|-----------|-----------------|
| NP_Etudiants | Groupe: SRV_Etudiants | 64=13, 65=6, 81="10" |
| NP_Profs | Groupe: SRV_Profs | 64=13, 65=6, 81="20" |
| NP_Admin | Groupe: SRV_Administration | 64=13, 65=6, 81="30" |
| NP_Guest | Groupe: SRV_Guests | 64=13, 65=6, 81="40" |
| NP_IT | Groupe: SRV_IT | 64=13, 65=6, 81="50" |
| NP_Default | (tout le reste) | 64=13, 65=6, 81="99" |

> ⚠️ **GOTCHA critique NPS** : L'attribut `Tunnel-Private-Group-ID` (81) doit être de type **STRING** "10" pas integer 10. Dans NPS : clic droit → Add → Vendor Specific attribute → valeur entre guillemets.

#### Certificat PEAP :
- Pour les PC du domaine : le certificat auto-signé du DC est automatiquement approuvé via GPO
- Pour les PC non-domaine (BYOD étudiants) : distribuer le certificat CA via clé USB ou QR code menant à la page de téléchargement (http://192.168.99.10/cert)

---

## 🧪 Tests de Validation (Séquence)

```
T1. show ip routing                           → "IP routing is enabled"
T2. show ip interface brief                   → 6 SVIs Up/Up
T3. ping 192.168.10.1 source vlan 50          → !!!!!
T4. ping 192.168.50.10 source vlan 10         → !!!!!  (inter-VLAN)
T5. show ip dhcp snooping                     → Fa0/1 trusted
T6. Brancher un PC sur Fa0/10 → obtenir IP    → 192.168.99.x d'abord
T7. Authentification 802.1X avec creds Étudiant → VLAN 10, IP 192.168.10.x
T8. show authentication sessions              → VLAN dynamique = 10
T9. Event Viewer DC → Event ID 6272           → Access granted, VLAN 10
T10. nslookup mediaschool.local               → résolution via 192.168.50.10
```

---

## ⚡ Limitations de cette Architecture

| Limitation | Impact | Alternative |
|-----------|--------|-------------|
| Internet perdu (RT2-IRIS débranché) | Pas d'accès web depuis les VLANs | Reconnexion RT2-IRIS ou routeur USB/Linux |
| 2960-S routing = CPU-based (pas ASIC) | ~150-200 Mbps max inter-VLAN | Acceptable pour ~50 users lab scolaire |
| Pas de routage dynamique (LAN Base) | Routes statiques uniquement | OK pour infra flat single-site |
| Pas de NAT sur 2960-S | Impossible de NATer vers internet | Nécessite un équipement upstream |

---

## 📌 Note Internet — Analyse des Options

Le 2960-S **ne supporte pas NAT**. Pour retrouver l'accès internet :

**Option A — Remettre RT2-IRIS en service** (recommandé si dispo)
- Reconnexion trunk Gi0/1 → Gi0/1
- Retrait `shutdown` sur Gi0/1 du switch
- SW2-IRIS route en local, RT2-IRIS fait uniquement le NAT/WAN
- `ip route 0.0.0.0 0.0.0.0 192.168.50.1` sur le switch

**Option B — PC Linux comme gateway NAT** (solution de secours lab)
```bash
# Sur le PC hôte Ubuntu — partage internet via USB Ethernet
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
# eth0 = interface WAN, enp0s3 = interface vers switch
```
Puis sur le switch : `ip route 0.0.0.0 0.0.0.0 192.168.50.X` (IP du PC Linux)

**Option C — Firewall pfSense en VM** (solution propre long terme)
- VM pfSense avec NIC bridged sur VLAN 50
- Remplace RT2-IRIS pour NAT + firewall
- Plus flexible et gratuit
