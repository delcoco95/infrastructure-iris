# ============================================================
# 05_create_users.ps1 — Création OUs, groupes et utilisateurs AD
# Projet : IRIS-NICE-2024-RP01
# Auteur  : Nedjmeddine Belloum
# Étape   : 5/6 — Après configuration NPS
# Prérequis : AD DS opérationnel, module ActiveDirectory disponible
# ============================================================

try {
    Write-Host "[5/6] Création des OUs, groupes et utilisateurs Active Directory..."
    Import-Module ActiveDirectory -ErrorAction Stop

    $base = "DC=mediaschool,DC=local"

    # ── Création des Unités Organisationnelles ────────────────
    Write-Host "[AD] Création des OUs..."
    $ous = @(
        @{ Name = "Utilisateurs";   Path = $base },
        @{ Name = "Etudiants";      Path = "OU=Utilisateurs,$base" },
        @{ Name = "BTS_SIO_2annee"; Path = "OU=Etudiants,OU=Utilisateurs,$base" },
        @{ Name = "SISR";           Path = "OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base" },
        @{ Name = "SLAM";           Path = "OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base" },
        @{ Name = "BTS_SIO_1annee"; Path = "OU=Etudiants,OU=Utilisateurs,$base" },
        @{ Name = "SISR";           Path = "OU=BTS_SIO_1annee,OU=Etudiants,OU=Utilisateurs,$base" },
        @{ Name = "SLAM";           Path = "OU=BTS_SIO_1annee,OU=Etudiants,OU=Utilisateurs,$base" },
        @{ Name = "Profs";          Path = "OU=Utilisateurs,$base" },
        @{ Name = "Administration"; Path = "OU=Utilisateurs,$base" },
        @{ Name = "Invites";        Path = "OU=Utilisateurs,$base" },
        @{ Name = "Groupes";        Path = $base },
        @{ Name = "Ordinateurs";    Path = $base },
        @{ Name = "PostesSalle";    Path = "OU=Ordinateurs,$base" },
        @{ Name = "PostesAdmin";    Path = "OU=Ordinateurs,$base" },
        @{ Name = "Serveurs";       Path = $base },
        @{ Name = "CompteService";  Path = "OU=Serveurs,$base" }
    )

    foreach ($ou in $ous) {
        New-ADOrganizationalUnit -Name $ou.Name -Path $ou.Path -ErrorAction SilentlyContinue
    }
    Write-Host "[OK] OUs créées."

    # ── Création des groupes de sécurité ─────────────────────
    Write-Host "[AD] Création des groupes..."
    $groups = @(
        "GRP_Etudiants_SISR",
        "GRP_Etudiants_SLAM",
        "GRP_Profs",
        "GRP_Administration",
        "GRP_Invites",
        "GRP_IT_Admin"
    )

    foreach ($g in $groups) {
        New-ADGroup -Name $g -GroupScope Global -GroupCategory Security `
            -Path "OU=Groupes,$base" -ErrorAction SilentlyContinue
    }
    Write-Host "[OK] Groupes créés."

    # ── Création des utilisateurs ─────────────────────────────
    Write-Host "[AD] Création des utilisateurs..."

    $users = @(
        # ── Étudiants SISR 2A ──
        @{ Sam = "nedj.belloum";       Name = "Nedj Belloum";       Pass = "PasswordSISR2_2026!"; OU = "OU=SISR,OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base"; Group = "GRP_Etudiants_SISR" },
        @{ Sam = "edib.saoud";         Name = "Edib Saoud";          Pass = "PasswordSISR2_2026!"; OU = "OU=SISR,OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base"; Group = "GRP_Etudiants_SISR" },
        @{ Sam = "julien.marcucci";    Name = "Julien Marcucci";     Pass = "PasswordSISR2_2026!"; OU = "OU=SISR,OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base"; Group = "GRP_Etudiants_SISR" },
        @{ Sam = "louka.lavenir";      Name = "Louka Lavenir";       Pass = "PasswordSISR2_2026!"; OU = "OU=SISR,OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base"; Group = "GRP_Etudiants_SISR" },
        @{ Sam = "omar.talibi";        Name = "Omar Talibi";         Pass = "PasswordSISR2_2026!"; OU = "OU=SISR,OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base"; Group = "GRP_Etudiants_SISR" },
        @{ Sam = "remi.bears";         Name = "Remi Bears";          Pass = "PasswordSISR2_2026!"; OU = "OU=SISR,OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base"; Group = "GRP_Etudiants_SISR" },
        @{ Sam = "said.ahmedmoussa";   Name = "Said Ahmed Moussa";   Pass = "PasswordSISR2_2026!"; OU = "OU=SISR,OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base"; Group = "GRP_Etudiants_SISR" },
        @{ Sam = "vincent.andreo";     Name = "Vincent Andreo";      Pass = "PasswordSISR2_2026!"; OU = "OU=SISR,OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base"; Group = "GRP_Etudiants_SISR" },
        @{ Sam = "hendrik.thouvenin";  Name = "Hendrik Thouvenin";   Pass = "PasswordSISR2_2026!"; OU = "OU=SISR,OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base"; Group = "GRP_Etudiants_SISR" },
        # ── Étudiants SLAM 2A ──
        @{ Sam = "yanis.adidi";        Name = "Yanis Adidi";         Pass = "PasswordSLAM2_2026!"; OU = "OU=SLAM,OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base"; Group = "GRP_Etudiants_SLAM" },
        @{ Sam = "mohamed.boukhatem";  Name = "Mohamed Boukhatem";   Pass = "PasswordSLAM2_2026!"; OU = "OU=SLAM,OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base"; Group = "GRP_Etudiants_SLAM" },
        @{ Sam = "klaudia.juhasz";     Name = "Klaudia Juhasz";      Pass = "PasswordSLAM2_2026!"; OU = "OU=SLAM,OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base"; Group = "GRP_Etudiants_SLAM" },
        @{ Sam = "denys.lyulchak";     Name = "Denys Lyulchak";      Pass = "PasswordSLAM2_2026!"; OU = "OU=SLAM,OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base"; Group = "GRP_Etudiants_SLAM" },
        @{ Sam = "kevin.senasson";     Name = "Kevin Senasson";      Pass = "PasswordSLAM2_2026!"; OU = "OU=SLAM,OU=BTS_SIO_2annee,OU=Etudiants,OU=Utilisateurs,$base"; Group = "GRP_Etudiants_SLAM" },
        # ── Professeurs ──
        @{ Sam = "yan.bourquard";      Name = "Yan Bourquard";       Pass = "Prof_IRIS_2026!"; OU = "OU=Profs,OU=Utilisateurs,$base"; Group = "GRP_Profs" },
        @{ Sam = "stephanie.tanzi";    Name = "Stephanie Tanzi";     Pass = "Prof_IRIS_2026!"; OU = "OU=Profs,OU=Utilisateurs,$base"; Group = "GRP_Profs" },
        @{ Sam = "terrence.ferut";     Name = "Terrence Ferut";      Pass = "Prof_IRIS_2026!"; OU = "OU=Profs,OU=Utilisateurs,$base"; Group = "GRP_Profs" },
        @{ Sam = "hayk.kaymakcilar";   Name = "Hayk Kaymakcilar";    Pass = "Prof_IRIS_2026!"; OU = "OU=Profs,OU=Utilisateurs,$base"; Group = "GRP_Profs" },
        @{ Sam = "raphael.tirintino";  Name = "Raphael Tirintino";   Pass = "Prof_IRIS_2026!"; OU = "OU=Profs,OU=Utilisateurs,$base"; Group = "GRP_Profs" },
        @{ Sam = "melanie.lejeune";    Name = "Melanie Lejeune";     Pass = "Prof_IRIS_2026!"; OU = "OU=Profs,OU=Utilisateurs,$base"; Group = "GRP_Profs" },
        @{ Sam = "lynda.hamidat";      Name = "Lynda Hamidat";       Pass = "Prof_IRIS_2026!"; OU = "OU=Profs,OU=Utilisateurs,$base"; Group = "GRP_Profs" },
        # ── Administration école ──
        @{ Sam = "marie.agnamazian";   Name = "Marie Agnamazian";    Pass = "Admin_IRIS_2026!"; OU = "OU=Administration,OU=Utilisateurs,$base"; Group = "GRP_Administration" },
        @{ Sam = "enzo.sun";           Name = "Enzo Sun";            Pass = "Admin_IRIS_2026!"; OU = "OU=Administration,OU=Utilisateurs,$base"; Group = "GRP_Administration" },
        # ── Invité de test ──
        @{ Sam = "invite.test";        Name = "Invite Test";         Pass = "Invite_IRIS_2026!"; OU = "OU=Invites,OU=Utilisateurs,$base"; Group = "GRP_Invites" },
        # ── Compte de service NPS ──
        @{ Sam = "svc_nps";            Name = "Service NPS RADIUS";  Pass = "SvcNPS_IRIS_2026!"; OU = "OU=CompteService,OU=Serveurs,$base"; Group = "" }
    )

    foreach ($u in $users) {
        $sp = ConvertTo-SecureString $u.Pass -AsPlainText -Force
        New-ADUser `
            -SamAccountName     $u.Sam `
            -Name               $u.Name `
            -AccountPassword    $sp `
            -Enabled            $true `
            -Path               $u.OU `
            -PasswordNeverExpires $false `
            -ChangePasswordAtLogon $false `
            -ErrorAction SilentlyContinue

        if ($u.Group -ne "") {
            Add-ADGroupMember -Identity $u.Group -Members $u.Sam -ErrorAction SilentlyContinue
        }
        Write-Host "[OK] Utilisateur créé : $($u.Sam)"
    }

    # ── Compte administrateur IT (Domain Admins) ─────────────
    Write-Host "[AD] Création du compte admin IT..."
    $sp = ConvertTo-SecureString "NVTech_Admin2026!" -AsPlainText -Force
    New-ADUser `
        -SamAccountName     "nedj.belloum.admin" `
        -Name               "Nedj Belloum Admin" `
        -GivenName          "Nedj" `
        -Surname            "Belloum" `
        -AccountPassword    $sp `
        -Enabled            $true `
        -Path               "OU=Administration,OU=Utilisateurs,$base" `
        -Description        "Compte administrateur IT - Usage exclusif administration" `
        -PasswordNeverExpires $false `
        -ChangePasswordAtLogon $false `
        -ErrorAction SilentlyContinue

    Add-ADGroupMember -Identity "GRP_IT_Admin"  -Members "nedj.belloum.admin" -ErrorAction SilentlyContinue
    Add-ADGroupMember -Identity "Domain Admins" -Members "nedj.belloum.admin" -ErrorAction SilentlyContinue
    Write-Host "[OK] Compte admin IT créé : nedj.belloum.admin (GRP_IT_Admin + Domain Admins)"

    # ── Délégation de lecture AD pour svc_nps ────────────────
    # Permet à NPS d'interroger l'AD pour l'authentification RADIUS
    Add-ADGroupMember -Identity "RAS and IAS Servers" -Members "svc_nps" -ErrorAction SilentlyContinue
    Write-Host "[OK] svc_nps ajouté au groupe 'RAS and IAS Servers'."

    Write-Host ""
    Write-Host "[OK] AD configuré : $(($users).Count + 1) utilisateurs, 6 groupes, 17 OUs."
    Write-Host "[NEXT] Exécuter : 06_configure_gpo.ps1"

} catch {
    Write-Error "[ERREUR] Création utilisateurs échouée : $_"
    exit 1
}
