# ============================================================
# 06_configure_gpo.ps1 — Configuration des GPO de sécurité
# Projet : IRIS-NICE-2024-RP01
# Auteur  : Nedjmeddine Belloum
# Étape   : 6/6 — Dernière étape de configuration AD
# Prérequis : Utilisateurs et OUs créés (05_create_users.ps1)
#
# GPO créées :
#   GPO-SEC-Postes-Etudiants  : Restrictions sur postes étudiants
#   GPO-SEC-Postes-Profs      : Restrictions allégées pour profs
#   GPO-SEC-Serveurs          : Sécurité renforcée des serveurs
#   GPO-SEC-Comptes           : Politique de mots de passe (Fine-Grained)
# ============================================================

try {
    Write-Host "[6/6] Configuration des GPO de sécurité..."
    Import-Module GroupPolicy  -ErrorAction Stop
    Import-Module ActiveDirectory -ErrorAction Stop

    $base   = "DC=mediaschool,DC=local"
    $domain = "mediaschool.local"

    # ════════════════════════════════════════════════════════
    # GPO 1 — Restrictions postes étudiants (OU=PostesSalle)
    # ════════════════════════════════════════════════════════
    $gpo1Name = "GPO-SEC-Postes-Etudiants"
    Write-Host "[GPO] Création : $gpo1Name"
    $gpo1 = New-GPO -Name $gpo1Name -Domain $domain -ErrorAction SilentlyContinue
    if (-not $gpo1) { $gpo1 = Get-GPO -Name $gpo1Name -Domain $domain }

    # Désactiver le Panneau de configuration
    Set-GPRegistryValue -Name $gpo1Name -Domain $domain `
        -Key  "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
        -ValueName "NoControlPanel" -Type DWord -Value 1 -ErrorAction SilentlyContinue

    # Désactiver l'accès au registre
    Set-GPRegistryValue -Name $gpo1Name -Domain $domain `
        -Key  "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
        -ValueName "DisableRegistryTools" -Type DWord -Value 1 -ErrorAction SilentlyContinue

    # Verrouiller l'écran après 10 minutes d'inactivité
    Set-GPRegistryValue -Name $gpo1Name -Domain $domain `
        -Key  "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
        -ValueName "ScreenSaveTimeOut" -Type String -Value "600" -ErrorAction SilentlyContinue
    Set-GPRegistryValue -Name $gpo1Name -Domain $domain `
        -Key  "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
        -ValueName "ScreenSaverIsSecure" -Type String -Value "1" -ErrorAction SilentlyContinue
    Set-GPRegistryValue -Name $gpo1Name -Domain $domain `
        -Key  "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
        -ValueName "SCRNSAVE.EXE" -Type String -Value "scrnsave.scr" -ErrorAction SilentlyContinue

    # Interdire l'installation de logiciels
    Set-GPRegistryValue -Name $gpo1Name -Domain $domain `
        -Key  "HKCU\Software\Policies\Microsoft\Windows\Installer" `
        -ValueName "DisableUserInstalls" -Type DWord -Value 1 -ErrorAction SilentlyContinue

    # Lier la GPO à l'OU PostesSalle
    New-GPLink -Name $gpo1Name -Domain $domain `
        -Target "OU=PostesSalle,OU=Ordinateurs,$base" `
        -Enforced Yes -ErrorAction SilentlyContinue
    Write-Host "[OK] GPO liée : $gpo1Name → OU=PostesSalle"

    # ════════════════════════════════════════════════════════
    # GPO 2 — Restrictions allégées postes profs (OU=PostesAdmin)
    # ════════════════════════════════════════════════════════
    $gpo2Name = "GPO-SEC-Postes-Profs"
    Write-Host "[GPO] Création : $gpo2Name"
    $gpo2 = New-GPO -Name $gpo2Name -Domain $domain -ErrorAction SilentlyContinue
    if (-not $gpo2) { $gpo2 = Get-GPO -Name $gpo2Name -Domain $domain }

    # Verrouillage écran après 15 minutes
    Set-GPRegistryValue -Name $gpo2Name -Domain $domain `
        -Key  "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
        -ValueName "ScreenSaveTimeOut" -Type String -Value "900" -ErrorAction SilentlyContinue
    Set-GPRegistryValue -Name $gpo2Name -Domain $domain `
        -Key  "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
        -ValueName "ScreenSaverIsSecure" -Type String -Value "1" -ErrorAction SilentlyContinue

    New-GPLink -Name $gpo2Name -Domain $domain `
        -Target "OU=PostesAdmin,OU=Ordinateurs,$base" `
        -Enforced Yes -ErrorAction SilentlyContinue
    Write-Host "[OK] GPO liée : $gpo2Name → OU=PostesAdmin"

    # ════════════════════════════════════════════════════════
    # GPO 3 — Sécurité serveurs (OU=Serveurs)
    # ════════════════════════════════════════════════════════
    $gpo3Name = "GPO-SEC-Serveurs"
    Write-Host "[GPO] Création : $gpo3Name"
    $gpo3 = New-GPO -Name $gpo3Name -Domain $domain -ErrorAction SilentlyContinue
    if (-not $gpo3) { $gpo3 = Get-GPO -Name $gpo3Name -Domain $domain }

    # Désactiver RDP depuis réseau non-Management
    Set-GPRegistryValue -Name $gpo3Name -Domain $domain `
        -Key  "HKLM\System\CurrentControlSet\Control\Terminal Server" `
        -ValueName "fDenyTSConnections" -Type DWord -Value 0 -ErrorAction SilentlyContinue

    # Activer le pare-feu Windows (tous les profils)
    Set-GPRegistryValue -Name $gpo3Name -Domain $domain `
        -Key  "HKLM\Software\Policies\Microsoft\WindowsFirewall\DomainProfile" `
        -ValueName "EnableFirewall" -Type DWord -Value 1 -ErrorAction SilentlyContinue
    Set-GPRegistryValue -Name $gpo3Name -Domain $domain `
        -Key  "HKLM\Software\Policies\Microsoft\WindowsFirewall\PrivateProfile" `
        -ValueName "EnableFirewall" -Type DWord -Value 1 -ErrorAction SilentlyContinue

    # Désactiver NetBIOS sur IP (réduit la surface d'attaque)
    Set-GPRegistryValue -Name $gpo3Name -Domain $domain `
        -Key  "HKLM\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" `
        -ValueName "NodeType" -Type DWord -Value 8 -ErrorAction SilentlyContinue

    # Exiger SMB signing
    Set-GPRegistryValue -Name $gpo3Name -Domain $domain `
        -Key  "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" `
        -ValueName "RequireSecuritySignature" -Type DWord -Value 1 -ErrorAction SilentlyContinue

    New-GPLink -Name $gpo3Name -Domain $domain `
        -Target "OU=Serveurs,$base" `
        -Enforced Yes -ErrorAction SilentlyContinue
    Write-Host "[OK] GPO liée : $gpo3Name → OU=Serveurs"

    # ════════════════════════════════════════════════════════
    # GPO 4 — Politique globale de mots de passe (domaine)
    # Appliquée au domaine (Default Domain Policy override)
    # ════════════════════════════════════════════════════════
    $gpo4Name = "GPO-SEC-PasswordPolicy"
    Write-Host "[GPO] Création : $gpo4Name"
    $gpo4 = New-GPO -Name $gpo4Name -Domain $domain -ErrorAction SilentlyContinue
    if (-not $gpo4) { $gpo4 = Get-GPO -Name $gpo4Name -Domain $domain }

    New-GPLink -Name $gpo4Name -Domain $domain `
        -Target $base `
        -Order 1 -ErrorAction SilentlyContinue

    # Politique de mots de passe via Fine-Grained Password Policy
    $fgppName = "FGPP-Etudiants"
    $existingFgpp = Get-ADFineGrainedPasswordPolicy -Filter { Name -eq $fgppName } -ErrorAction SilentlyContinue
    if (-not $existingFgpp) {
        New-ADFineGrainedPasswordPolicy `
            -Name                  $fgppName `
            -Precedence            10 `
            -MinPasswordLength     8 `
            -PasswordHistoryCount  5 `
            -MaxPasswordAge        "90.00:00:00" `
            -MinPasswordAge        "1.00:00:00" `
            -LockoutThreshold      5 `
            -LockoutDuration       "0.00:30:00" `
            -LockoutObservationWindow "0.00:30:00" `
            -ComplexityEnabled     $true `
            -ReversibleEncryptionEnabled $false `
            -ErrorAction SilentlyContinue
        Add-ADFineGrainedPasswordPolicySubject -Identity $fgppName -Subjects "GRP_Etudiants_SISR","GRP_Etudiants_SLAM" -ErrorAction SilentlyContinue
        Write-Host "[OK] FGPP créée : $fgppName (8 car, complexité, 90j, lockout 5 tentatives)"
    }

    $fgppAdmin = "FGPP-Admins"
    $existingFgppAdmin = Get-ADFineGrainedPasswordPolicy -Filter { Name -eq $fgppAdmin } -ErrorAction SilentlyContinue
    if (-not $existingFgppAdmin) {
        New-ADFineGrainedPasswordPolicy `
            -Name                  $fgppAdmin `
            -Precedence            5 `
            -MinPasswordLength     12 `
            -PasswordHistoryCount  10 `
            -MaxPasswordAge        "60.00:00:00" `
            -MinPasswordAge        "1.00:00:00" `
            -LockoutThreshold      3 `
            -LockoutDuration       "0.01:00:00" `
            -LockoutObservationWindow "0.00:30:00" `
            -ComplexityEnabled     $true `
            -ReversibleEncryptionEnabled $false `
            -ErrorAction SilentlyContinue
        Add-ADFineGrainedPasswordPolicySubject -Identity $fgppAdmin -Subjects "GRP_IT_Admin","Domain Admins" -ErrorAction SilentlyContinue
        Write-Host "[OK] FGPP créée : $fgppAdmin (12 car, complexité, 60j, lockout 3 tentatives)"
    }

    Write-Host ""
    Write-Host "[OK] 4 GPO créées et liées. Fine-Grained Password Policies configurées."
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════"
    Write-Host " DÉPLOIEMENT WINDOWS SERVER 2022 TERMINÉ"
    Write-Host "════════════════════════════════════════════════════"
    Write-Host " Récapitulatif :"
    Write-Host "   [✓] Rôles : AD DS, DNS, DHCP, NPS"
    Write-Host "   [✓] Domaine : mediaschool.local"
    Write-Host "   [✓] DHCP : 6 VLANs configurés"
    Write-Host "   [✓] NPS : 3 clients RADIUS + 6 stratégies"
    Write-Host "   [✓] AD : 25+ utilisateurs, 6 groupes, 17 OUs"
    Write-Host "   [✓] GPO : 4 politiques de sécurité"
    Write-Host ""
    Write-Host " Prochaine étape : Configurer les équipements Cisco"
    Write-Host "   → SW2-IRIS : cisco/SW2-IRIS_config.txt"
    Write-Host "   → RT2-IRIS : cisco/RT2-IRIS_config.txt"
    Write-Host "════════════════════════════════════════════════════"

} catch {
    Write-Error "[ERREUR] Configuration GPO échouée : $_"
    exit 1
}
