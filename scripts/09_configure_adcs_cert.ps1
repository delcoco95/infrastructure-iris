# 09_configure_adcs_cert.ps1 - ADCS Enterprise CA + Certificat NPS
# Projet : IRIS-NICE-2024-RP01 | Exec : Sur DC-IRIS-01, en Administrateur

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step { param($msg) Write-Host "[STEP] $msg" -ForegroundColor Cyan   }
function Write-OK   { param($msg) Write-Host "[OK]   $msg" -ForegroundColor Green  }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "[FAIL] $msg" -ForegroundColor Red    }

try {

    # ETAPE 1 - Installation du role ADCS
    Write-Step "Installation du role ADCS..."
    $f = Get-WindowsFeature -Name "ADCS-Cert-Authority"
    if ($f.Installed) {
        Write-Warn "ADCS deja installe."
    } else {
        Install-WindowsFeature -Name "ADCS-Cert-Authority" -IncludeManagementTools -ErrorAction Stop
        Write-OK "Role ADCS installe."
    }

    # ETAPE 2 - Configuration CA Enterprise Root
    Write-Step "Configuration CA IRIS-CA..."
    $svc = Get-Service -Name "CertSvc" -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        Write-Warn "CA deja active."
    } else {
        Import-Module ADCSDeployment -ErrorAction Stop
        Install-AdcsCertificationAuthority -CAType "EnterpriseRootCA" -CACommonName "IRIS-CA" -CADistinguishedNameSuffix "DC=mediaschool,DC=local" -KeyLength 2048 -HashAlgorithmName "SHA256" -ValidityPeriod "Years" -ValidityPeriodUnits 5 -DatabaseDirectory "C:\Windows\System32\CertLog" -LogDirectory "C:\Windows\System32\CertLog" -Force -ErrorAction Stop
        Restart-Service -Name "CertSvc" -Force
        Start-Sleep -Seconds 5
        Write-OK "CA IRIS-CA configuree."
    }

    # ETAPE 3 - GPO auto-enrolement
    Write-Step "Configuration GPO auto-enrolement..."
    $gpoName = "GPO-CERT-AutoEnrollment"
    Import-Module GroupPolicy -ErrorAction Stop
    $gpo = Get-GPO -Name $gpoName -Domain "mediaschool.local" -ErrorAction SilentlyContinue
    if (-not $gpo) { $gpo = New-GPO -Name $gpoName -Domain "mediaschool.local" -ErrorAction Stop; Write-OK "GPO creee." }
    Set-GPRegistryValue -Name $gpoName -Domain "mediaschool.local" -Key "HKLM\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment" -ValueName "AEPolicy" -Type DWord -Value 7 -ErrorAction SilentlyContinue
    Set-GPRegistryValue -Name $gpoName -Domain "mediaschool.local" -Key "HKCU\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment" -ValueName "AEPolicy" -Type DWord -Value 7 -ErrorAction SilentlyContinue
    New-GPLink -Name $gpoName -Domain "mediaschool.local" -Target "DC=mediaschool,DC=local" -Order 1 -ErrorAction SilentlyContinue
    Write-OK "GPO auto-enrolement configuree."

    # ETAPE 4 - Activer template RAS and IAS Server
    Write-Step "Activation template RASAndIASServer..."
    certutil -SetCATemplates "+RASAndIASServer" 2>&1 | Out-Null
    Write-OK "Template RASAndIASServer active."

    # ETAPE 5 - Enrolement du certificat NPS
    Write-Step "Enrolement du certificat NPS pour PEAP..."
    gpupdate /force 2>&1 | Out-Null
    certutil -pulse 2>&1 | Out-Null
    Start-Sleep -Seconds 15

    $certs = Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.EnhancedKeyUsageList -match "1.3.6.1.5.5.7.3.1" }

    if ($certs.Count -gt 0) {
        Write-OK "Certificat(s) trouves :"
        foreach ($c in $certs) { Write-OK "  $($c.Subject) | $($c.Thumbprint) | Expire: $($c.NotAfter)" }
    } else {
        Write-Warn "Pas de cert via pulse - tentative enrollnow..."
        certutil -enrollnow "Computer" 2>&1 | Out-Null
        Start-Sleep -Seconds 15
        $certs = Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.EnhancedKeyUsageList -match "1.3.6.1.5.5.7.3.1" }
        if ($certs.Count -eq 0) {
            Write-Fail "ECHEC - Aucun certificat. Ouvrir certtmpl.msc -> RAS and IAS Server -> Securite -> Ajouter DC -> Cocher Inscrire"
            exit 1
        }
    }

    # ETAPE 6 - Export CA racine
    Write-Step "Export certificat CA racine..."
    certutil -ca.cert "C:\IRIS-CA-Root.cer" 2>&1 | Out-Null
    certutil -dspublish -f "C:\IRIS-CA-Root.cer" RootCA 2>&1 | Out-Null
    Write-OK "CA Root exportee et publiee dans AD."

    # ETAPE 7 - Validation
    Write-Step "Validation finale..."
    $ok = Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.EnhancedKeyUsageList -match "1.3.6.1.5.5.7.3.1" -and $_.NotAfter -gt (Get-Date) }
    if ($ok.Count -gt 0) {
        $ok[0].Thumbprint | Out-File "C:\NPS_Cert_Thumbprint.txt" -Force
        Write-OK "SUCCES - Cert valide: $($ok[0].Thumbprint) exp $($ok[0].NotAfter)"
        Write-Host "===== ADCS CONFIGURE - WiFi PEAP operationnel =====" -ForegroundColor Green
        Write-Host "Distribuer C:\IRIS-CA-Root.cer aux clients WiFi" -ForegroundColor Green
    } else {
        Write-Fail "ECHEC - Aucun cert valide pour NPS/PEAP"
        exit 1
    }

} catch {
    Write-Fail "ERREUR : $_"
    exit 1
}
