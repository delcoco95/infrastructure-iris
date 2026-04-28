# ============================================================
# 08_post_join_client.ps1 — PC-CLIENT-IRIS — Post-jonction domaine
# À exécuter APRÈS le premier reboot via :
#   vagrant provision client-win11 --provision-with 08_post_join
# BTS SIO SISR — RP01 IRIS Nice — Nedjmeddine Belloum
# ============================================================

$ErrorActionPreference = "Continue"

function Log($msg) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg" -ForegroundColor Green
}

$SRVLinux = "192.168.50.20"
$desktop  = [System.Environment]::GetFolderPath("CommonDesktopDirectory")

# ── 1. Vérifier la jonction domaine ───────────────────────────
Log "Vérification jonction domaine..."
$domain = (Get-WmiObject Win32_ComputerSystem).Domain
Log "Machine jointe à : $domain"

# ── 2. Désactiver IE Enhanced Security (facilite les tests web) ─
Log "Désactivation IE Enhanced Security Configuration..."
$adminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$userKey  = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $adminKey -Name "IsInstalled" -Value 0 -ErrorAction SilentlyContinue
Set-ItemProperty -Path $userKey  -Name "IsInstalled" -Value 0 -ErrorAction SilentlyContinue

# ── 3. Ajouter sites intranet en zone de confiance IE/Edge ─────
Log "Ajout des sites internes en zone de confiance..."
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains"
New-Item -Path "$regPath\192.168.50.20" -Force | Out-Null
New-ItemProperty -Path "$regPath\192.168.50.20" -Name "http" -Value 1 -PropertyType DWORD -Force | Out-Null

# ── 4. Ouvrir automatiquement les URLs de test au démarrage ───
Log "Création des raccourcis bureau de test (post-jonction)..."
$wsh = New-Object -ComObject WScript.Shell

@(
    @{ Name = "GLPI (Parc + Tickets)";     URL = "http://$SRVLinux`:8082" },
    @{ Name = "Nextcloud (Fichiers)";       URL = "http://$SRVLinux`:8081" },
    @{ Name = "Grafana (Supervision)";      URL = "http://$SRVLinux`:3000" }
) | ForEach-Object {
    $link = $wsh.CreateShortcut("$desktop\$($_.Name).url")
    $link.TargetPath = $_.URL
    $link.Save()
}

# ── 5. Rapport de jonction ─────────────────────────────────────
Log "=== RAPPORT POST-JONCTION ==="
Log "Machine : $(hostname)"
Log "Domaine : $domain"
Log "IP VM   : 192.168.50.30"
Log "DC IRIS : 192.168.50.10"
Log ""
Log "Comptes disponibles pour test :"
Log "  Etudiant  : nedj.belloum@mediaschool.local  / PasswordSISR2_2026!"
Log "  Professeur: yan.bourquard@mediaschool.local / Prof_IRIS_2026!"
Log "  Admin IT  : marie.agnamazian@mediaschool.local / Admin_IRIS_2026!"
Log ""
Log "Services Docker (SRV-LINUX-IRIS) :"
Log "  GLPI      : http://$SRVLinux`:8082"
Log "  Nextcloud : http://$SRVLinux`:8081"
Log "  Grafana   : http://$SRVLinux`:3000"
Log ""
Log "=> Déconnectez-vous et reconnectez-vous avec un compte de test AD"
Log "=> Utilisez les raccourcis sur le Bureau pour accéder aux services"
