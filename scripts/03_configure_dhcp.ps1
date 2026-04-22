# ============================================================
# 03_configure_dhcp.ps1 — Configuration des étendues DHCP
# Projet : IRIS-NICE-2024-RP01
# Auteur  : Nedjmeddine Belloum
# Étape   : 3/6 — Après promotion AD et second redémarrage
# Prérequis : AD DS fonctionnel, DC-IRIS-01.mediaschool.local résolu
# ============================================================

try {
    Write-Host "[3/6] Configuration des étendues DHCP pour 6 VLANs..."
    Import-Module DHCPServer -ErrorAction Stop

    # Autorisation du serveur DHCP dans l'AD
    try {
        Add-DhcpServerInDC -DnsName "DC-IRIS-01.mediaschool.local" -IPAddress 192.168.50.10 -ErrorAction Stop
        Write-Host "[OK] Serveur DHCP autorisé dans l'AD."
    } catch {
        # Tenter via netsh si cmdlet PS échoue (double-hop)
        Write-Host "[WARN] Add-DhcpServerInDC échoué, tentative netsh..."
        netsh dhcp add server DC-IRIS-01.mediaschool.local 192.168.50.10
        Write-Host "[OK] Autorisation DHCP via netsh."
    }

    # Définition des étendues par VLAN
    $scopes = @(
        @{
            Name   = "VLAN10_Etudiants"
            Start  = "192.168.10.100"
            End    = "192.168.10.220"
            Subnet = "192.168.10.0"
            GW     = "192.168.10.1"
            DNS    = "192.168.50.10"
            Lease  = "0.08:00:00"
        },
        @{
            Name   = "VLAN20_Profs"
            Start  = "192.168.20.100"
            End    = "192.168.20.150"
            Subnet = "192.168.20.0"
            GW     = "192.168.20.1"
            DNS    = "192.168.50.10"
            Lease  = "1.00:00:00"
        },
        @{
            Name   = "VLAN30_Administration"
            Start  = "192.168.30.100"
            End    = "192.168.30.130"
            Subnet = "192.168.30.0"
            GW     = "192.168.30.1"
            DNS    = "192.168.50.10"
            Lease  = "1.00:00:00"
        },
        @{
            Name   = "VLAN40_Invites"
            Start  = "192.168.40.100"
            End    = "192.168.40.200"
            Subnet = "192.168.40.0"
            GW     = "192.168.40.1"
            DNS    = "8.8.8.8"
            Lease  = "0.02:00:00"
        },
        @{
            Name   = "VLAN50_Management"
            Start  = "192.168.50.50"
            End    = "192.168.50.90"
            Subnet = "192.168.50.0"
            GW     = "192.168.50.1"
            DNS    = "192.168.50.10"
            Lease  = "2.00:00:00"
        },
        @{
            Name   = "VLAN99_PreAuth"
            Start  = "192.168.99.100"
            End    = "192.168.99.200"
            Subnet = "192.168.99.0"
            GW     = "192.168.99.1"
            DNS    = "8.8.8.8"
            Lease  = "0.01:00:00"
        }
    )

    foreach ($s in $scopes) {
        # Vérifier si le scope existe déjà
        $existing = Get-DhcpServerv4Scope -ScopeId $s.Subnet -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "[SKIP] Étendue déjà existante : $($s.Name)"
            continue
        }
        Add-DhcpServerv4Scope `
            -Name        $s.Name `
            -StartRange  $s.Start `
            -EndRange    $s.End `
            -SubnetMask  "255.255.255.0" `
            -LeaseDuration $s.Lease `
            -State       "Active" `
            -ErrorAction Stop

        Set-DhcpServerv4OptionValue `
            -ScopeId   $s.Subnet `
            -Router    $s.GW `
            -DnsServer $s.DNS `
            -ErrorAction SilentlyContinue

        Write-Host "[OK] Étendue créée : $($s.Name)"
    }

    # Exclusion des équipements à IP fixe dans VLAN 50 Management
    # (DC .10, Switch .2, AP .24, Routeur .1, SRV-LINUX .20)
    Add-DhcpServerv4ExclusionRange `
        -ScopeId    "192.168.50.0" `
        -StartRange "192.168.50.1" `
        -EndRange   "192.168.50.30" `
        -ErrorAction Stop
    Write-Host "[OK] Exclusion VLAN50 : 192.168.50.1-30 (équipements fixes)."

    # Option DNS secondaire (8.8.8.8) pour les scopes utilisant le DC comme DNS
    foreach ($subnet in @("192.168.10.0","192.168.20.0","192.168.30.0","192.168.50.0")) {
        Set-DhcpServerv4OptionValue -ScopeId $subnet -DnsServer "192.168.50.10","8.8.8.8" -ErrorAction SilentlyContinue
    }

    Write-Host "[OK] DHCP configuré pour 6 VLANs."
    Write-Host "[NEXT] Exécuter : 04_configure_nps.ps1"

} catch {
    Write-Error "[ERREUR] Configuration DHCP échouée : $_"
    exit 1
}
