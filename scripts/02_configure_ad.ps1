# ============================================================
# 02_configure_ad.ps1 — Promotion en contrôleur de domaine
# Projet : IRIS-NICE-2024-RP01
# Auteur  : Nedjmeddine Belloum
# Étape   : 2/6 — Après redémarrage du script 01
# Prérequis : Rôle AD DS installé, IP fixe 192.168.50.10
# ============================================================

try {
    Write-Host "[2/6] Promotion en contrôleur de domaine mediaschool.local..."

    $SecurePassword = ConvertTo-SecureString "NVTech_Admin2026!" -AsPlainText -Force

    Install-ADDSForest `
        -DomainName                    "mediaschool.local" `
        -DomainNetbiosName             "MEDIASCHOOL" `
        -DomainMode                    "WinThreshold" `
        -ForestMode                    "WinThreshold" `
        -DatabasePath                  "C:\Windows\NTDS" `
        -LogPath                       "C:\Windows\NTDS" `
        -SysvolPath                    "C:\Windows\SYSVOL" `
        -SafeModeAdministratorPassword $SecurePassword `
        -InstallDns `
        -Force `
        -NoRebootOnCompletion

    Write-Host "[OK] Promotion en contrôleur de domaine terminée."
    Write-Host "[INFO] Redémarrage automatique dans 10 secondes..."
    Write-Host "[NEXT] Après redémarrage : exécuter 03_configure_dhcp.ps1"
    Start-Sleep -Seconds 10
    Restart-Computer -Force

} catch {
    Write-Error "[ERREUR] Promotion AD échouée : $_"
    exit 1
}
