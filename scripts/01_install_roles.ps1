# ============================================================
# 01_install_roles.ps1 — Installation des rôles Windows Server
# Projet : IRIS-NICE-2024-RP01
# Auteur  : Nedjmeddine Belloum
# Étape   : 1/6 — À exécuter en premier, avant toute promotion AD
# Prérequis : Windows Server 2022, droits Administrateur local
# ============================================================

try {
    Write-Host "[1/6] Installation des rôles Windows Server..."

    # Rôles principaux
    Install-WindowsFeature -Name AD-Domain-Services  -IncludeManagementTools -ErrorAction Stop
    Install-WindowsFeature -Name DNS                 -IncludeManagementTools -ErrorAction Stop
    Install-WindowsFeature -Name DHCP                -IncludeManagementTools -ErrorAction Stop
    Install-WindowsFeature -Name NPAS                -IncludeManagementTools -ErrorAction Stop

    # Outils d'administration distante (RSAT)
    Install-WindowsFeature -Name RSAT-AD-Tools       -ErrorAction Stop
    Install-WindowsFeature -Name RSAT-DHCP            -ErrorAction Stop
    Install-WindowsFeature -Name RSAT-NPAS           -ErrorAction Stop

    Write-Host "[OK] Tous les rôles installés avec succès."
    Write-Host "[INFO] Redémarrage automatique dans 10 secondes..."
    Write-Host "[NEXT] Après redémarrage : exécuter 02_configure_ad.ps1"
    Start-Sleep -Seconds 10
    Restart-Computer -Force

} catch {
    Write-Error "[ERREUR] Installation des rôles échouée : $_"
    exit 1
}
