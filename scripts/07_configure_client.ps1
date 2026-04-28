# ============================================================
# 07_configure_client.ps1 — PC-CLIENT-IRIS — Windows 11 Enterprise
# Jonction au domaine mediaschool.local + préparation tests
# BTS SIO SISR — RP01 IRIS Nice — Nedjmeddine Belloum
# Comptes tests :
#   Étudiant : nedj.belloum       / PasswordSISR2_2026!
#   Professeur: yan.bourquard     / Prof_IRIS_2026!
#   Admin IT  : marie.agnamazian  / Admin_IRIS_2026!
# ============================================================

$ErrorActionPreference = "Stop"

function Log($msg) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg" -ForegroundColor Cyan
}

# ── Variables ──────────────────────────────────────────────────
$DomainName     = "mediaschool.local"
$DomainDC       = "192.168.50.10"
$DomainAdmin    = "vagrant"
$DomainAdminPwd = "vagrant"
$SRVLinux       = "192.168.50.20"

# ── 1. Clavier AZERTY Français ─────────────────────────────────
Log "Configuration du clavier AZERTY Français..."
Set-WinUserLanguageList -LanguageList fr-FR -Force
Set-WinUILanguageOverride -Language fr-FR
Set-Culture fr-FR
Set-WinSystemLocale fr-FR
Set-TimeZone -Id "Romance Standard Time"

# ── 2. DNS pointé vers le DC ───────────────────────────────────
Log "Configuration DNS -> $DomainDC..."
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -notlike "*Loopback*" } | Select-Object -First 1
Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $DomainDC
ipconfig /flushdns | Out-Null

# Attendre que le DC soit joignable
Log "Test de joignabilité du DC ($DomainDC)..."
$retries = 0
do {
    $ping = Test-Connection -ComputerName $DomainDC -Count 1 -Quiet
    if (-not $ping) {
        $retries++
        Log "DC non joignable, tentative $retries/15 — attente 10s..."
        Start-Sleep -Seconds 10
    }
} while (-not $ping -and $retries -lt 15)

if (-not $ping) {
    Write-Error "DC $DomainDC inaccessible après 15 tentatives. Vérifier que la VM dc-iris est démarrée."
}

# Résolution DNS du domaine
Log "Résolution DNS de $DomainName..."
$dnsOk = Resolve-DnsName -Name $DomainName -Server $DomainDC -ErrorAction SilentlyContinue
if (-not $dnsOk) {
    Write-Error "Résolution DNS de $DomainName échouée."
}
Log "DNS OK : $DomainName résolu."

# ── 3. Renommer la machine ──────────────────────────────────────
Log "Renommage de la machine en PC-CLIENT-IRIS..."
$currentName = $env:COMPUTERNAME
if ($currentName -ne "PC-CLIENT-IRIS") {
    Rename-Computer -NewName "PC-CLIENT-IRIS" -Force
    Log "Machine renommée (prise en compte après reboot)."
}

# ── 4. Jonction au domaine ─────────────────────────────────────
Log "Jonction au domaine $DomainName..."
$secPwd = ConvertTo-SecureString $DomainAdminPwd -AsPlainText -Force
$cred   = New-Object System.Management.Automation.PSCredential("$DomainAdmin@$DomainName", $secPwd)

try {
    Add-Computer -DomainName $DomainName -Credential $cred -OUPath "OU=PostesAdmin,OU=Ordinateurs,DC=mediaschool,DC=local" -Force
    Log "Jonction domaine réussie — redémarrage dans 15s..."
} catch {
    Log "Erreur jonction domaine: $_"
    Log "Tentative jonction sans OU spécifique..."
    Add-Computer -DomainName $DomainName -Credential $cred -Force
    Log "Jonction réussie (OU par défaut)."
}

# ── 5. Créer les raccourcis sur le Bureau ──────────────────────
Log "Création des raccourcis de test sur le Bureau..."
$desktop = [System.Environment]::GetFolderPath("CommonDesktopDirectory")

$shortcuts = @(
    @{ Name = "GLPI - Parc Informatique";  URL = "http://$SRVLinux`:8082" },
    @{ Name = "Nextcloud - Stockage";      URL = "http://$SRVLinux`:8081" },
    @{ Name = "Grafana - Supervision";     URL = "http://$SRVLinux`:3000" },
    @{ Name = "Prometheus - Métriques";    URL = "http://$SRVLinux`:9090" }
)

$wsh = New-Object -ComObject WScript.Shell
foreach ($sc in $shortcuts) {
    $link = $wsh.CreateShortcut("$desktop\$($sc.Name).url")
    $link.TargetPath = $sc.URL
    $link.Save()
    Log "Raccourci créé : $($sc.Name)"
}

# ── 6. Fichier de credentials de test ─────────────────────────
Log "Création du fichier de credentials de test..."
$credFile = "$desktop\CREDENTIALS_TEST.txt"
@"
====================================================
  COMPTES DE TEST — RP01 IRIS NICE
  BTS SIO SISR — Nedjmeddine Belloum
====================================================

DOMAINE : mediaschool.local
DC      : $DomainDC
SRV     : $SRVLinux

-- COMPTE ÉTUDIANT (VLAN 10 attendu) --
  Utilisateur : nedj.belloum@mediaschool.local
  Mot de passe: PasswordSISR2_2026!
  Groupe      : GRP_Etudiants_SISR
  VLAN NPS    : 10 (192.168.10.x)

-- COMPTE PROFESSEUR (VLAN 20 attendu) --
  Utilisateur : yan.bourquard@mediaschool.local
  Mot de passe: Prof_IRIS_2026!
  Groupe      : GRP_Profs
  VLAN NPS    : 20 (192.168.20.x)

-- COMPTE ADMIN IT (VLAN 30 attendu) --
  Utilisateur : marie.agnamazian@mediaschool.local
  Mot de passe: Admin_IRIS_2026!
  Groupe      : GRP_Administration
  VLAN NPS    : 30 (192.168.30.x)

-- SERVICES À TESTER --
  GLPI      : http://$SRVLinux`:8082
  Nextcloud : http://$SRVLinux`:8081
  Grafana   : http://$SRVLinux`:3000 (admin / Grafana_IRIS_2026!)

-- JONCTION DOMAINE --
  Compte admin domaine : vagrant@mediaschool.local
  Mot de passe         : vagrant
====================================================
"@ | Out-File -FilePath $credFile -Encoding UTF8

Log "Fichier de credentials créé sur le Bureau."

# ── 7. Redémarrage ─────────────────────────────────────────────
Log "Redémarrage pour finaliser la jonction domaine..."
Start-Sleep -Seconds 5
Restart-Computer -Force
