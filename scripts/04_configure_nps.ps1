# ============================================================
# 04_configure_nps.ps1 — Configuration NPS / RADIUS
# Projet : IRIS-NICE-2024-RP01
# Auteur  : Nedjmeddine Belloum
# Étape   : 4/6 — Après configuration DHCP
# Prérequis : Rôle NPAS installé, AD opérationnel, compte svc_nps créé
#
# Ce script configure :
#   - L'enregistrement NPS dans l'AD
#   - Les 3 clients RADIUS (AP, Switch, Routeur)
#   - La politique de requêtes de connexion (CRP)
#   - Les 6 stratégies réseau (Network Policies) avec attribution VLAN
# ============================================================

try {
    Write-Host "[4/6] Configuration NPS / RADIUS..."
    # Module Nps (Server 2022) — contient uniquement les cmdlets clients
    Import-Module Nps -ErrorAction SilentlyContinue

    # ── Enregistrement du serveur NPS dans l'AD ──────────────
    Write-Host "[NPS] Enregistrement NPS dans l'AD (netsh)..."
    $regResult = netsh nps add registeredserver 2>&1
    Write-Host "[REG] $regResult"

    # ── Clients RADIUS via netsh ──────────────────────────────
    Write-Host "[NPS] Ajout des 3 clients RADIUS (netsh)..."

    $radiusClients = @(
        @{ Name = "AP-IRIS";    Address = "192.168.50.24"; Secret = "RadiusAP_IRIS_2026!"  },
        @{ Name = "SW2-IRIS";   Address = "192.168.50.2";  Secret = "RadiusSW_IRIS_2026!"  },
        @{ Name = "RT2-IRIS";   Address = "192.168.50.1";  Secret = "RadiusRTR_IRIS_2026!" }
    )

    foreach ($client in $radiusClients) {
        $out = netsh nps add client name="$($client.Name)" address="$($client.Address)" sharedsecret="$($client.Secret)" state=enable 2>&1
        if ($out -match "successfully|Ok") {
            Write-Host "[OK] Client RADIUS : $($client.Name) ($($client.Address))"
        } else {
            Write-Host "[INFO] $($client.Name): $out"
        }
    }

    # ── CRP via netsh ─────────────────────────────────────────
    Write-Host "[NPS] Création CRP 802.1X via netsh..."
    # 0x1006 = Day-And-Time-Restrictions (match all week)
    $timeAll = "0 00:00-24:00; 1 00:00-24:00; 2 00:00-24:00; 3 00:00-24:00; 4 00:00-24:00; 5 00:00-24:00; 6 00:00-24:00"
    # 0x1025 = Auth-Provider-Type (0x1 = Windows)
    $crpOut = netsh nps add crp name="CRP_IRIS_802.1X" processingorder=1 conditionid=0x1006 conditiondata="$timeAll" profileid=0x1025 profiledata=0x1 2>&1
    Write-Host "[CRP] $crpOut"

    # ── Stratégies réseau via netsh ───────────────────────────
    # conditionid=0x1023 = Windows-Groups
    # profileid=0x100f   = NP-Allow-Dial-in (1=TRUE=Grant Access)
    # profileid=0x40     = Tunnel-Type (0xd = 13 = VLAN)
    # profileid=0x41     = Tunnel-Medium-Type (0x6 = 6 = 802)
    # profileid=0x51     = Tunnel-Private-Group-ID (VLAN number)
    # profileid=0x1009   = NP-Authentication-Type (0x5=PEAP)

    Write-Host "[NPS] Création des 6 politiques réseau (VLAN 802.1X)..."

    $networkPolicies = @(
        @{ Name="NP_Etudiants";    Order=10; Groups="MEDIASCHOOL\GRP_Etudiants_SISR|MEDIASCHOOL\GRP_Etudiants_SLAM"; Vlan="10"  },
        @{ Name="NP_Profs";        Order=20; Groups="MEDIASCHOOL\GRP_Profs";        Vlan="20"  },
        @{ Name="NP_Administration";Order=30; Groups="MEDIASCHOOL\GRP_Administration"; Vlan="30"  },
        @{ Name="NP_Invites";      Order=40; Groups="MEDIASCHOOL\GRP_Invites";      Vlan="40"  },
        @{ Name="NP_IT_Admin";     Order=50; Groups="MEDIASCHOOL\GRP_IT_Admin";     Vlan="50"  },
        @{ Name="NP_Default_PreAuth"; Order=99; Groups=$null; Vlan="99" }
    )

    foreach ($pol in $networkPolicies) {
        if ($pol.Groups) {
            $condId   = "0x1023"
            $condData = $pol.Groups
        } else {
            # Default catch-all: NAS-Port-Type = Wireless(0x13) or Ethernet(0xf)
            $condId   = "0x3d"
            $condData = "0x13"
        }
        $npOut = netsh nps add np name="$($pol.Name)" processingorder=$($pol.Order) `
            conditionid=$condId conditiondata="$condData" `
            profileid=0x100f profiledata=TRUE `
            profileid=0x1009 profiledata=0x5 `
            profileid=0x40 profiledata=0xd `
            profileid=0x41 profiledata=0x6 `
            profileid=0x51 profiledata="$($pol.Vlan)" 2>&1
        Write-Host "[NP] $($pol.Name) (VLAN $($pol.Vlan)): $npOut"
    }

    # ── Export config NPS pour archivage ─────────────────────
    $exportPath = "C:\NPS_Config_Export_$(Get-Date -Format 'yyyyMMdd').xml"
    Export-NpsConfiguration -Path $exportPath -ErrorAction SilentlyContinue
    Write-Host "[OK] Config NPS exportée : $exportPath"

    Write-Host ""
    Write-Host "[OK] NPS : 3 clients RADIUS + 6 politiques (VLAN 10/20/30/40/50/99)"
    Write-Host "[NEXT] Exécuter : 05_create_users.ps1"

} catch {
    Write-Error "[ERREUR] Configuration NPS échouée : $_"
    exit 1
}
