# ============================================================
# 05_fix_nps_peap.ps1 — Fix NPS PEAP + politiques VLAN
# Doit être lancé DEPUIS DC-IRIS-01 (en local ou via WinRM)
# ============================================================

Write-Host "[1] Reset config NPS..."
netsh nps reset config | Out-Null
Start-Sleep 3

Write-Host "[2] Démarrage IAS..."
sc.exe start IAS | Out-Null
Start-Sleep 8
$state = (sc.exe query IAS | Select-String "STATE").ToString()
Write-Host "    IAS: $state"

Write-Host "[3] Certificat PEAP..."
$cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Subject -match "dc-iris"} | Select-Object -First 1
if (!$cert) {
    $cert = New-SelfSignedCertificate `
        -DnsName "dc-iris-01.mediaschool.local","DC-IRIS-01" `
        -CertStoreLocation "Cert:\LocalMachine\My" `
        -KeySpec KeyExchange `
        -KeyUsage KeyEncipherment,DigitalSignature `
        -KeyLength 2048 `
        -HashAlgorithm SHA256 `
        -NotAfter (Get-Date).AddYears(5) `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1")
    Write-Host "    Cert créé: $($cert.Thumbprint)"
} else {
    Write-Host "    Cert existant: $($cert.Thumbprint)"
}
$thumb = $cert.Thumbprint

Write-Host "[4] Configuration PEAP via registre IAS..."
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\IAS\Properties"
Set-ItemProperty -Path $regPath -Name "Certificate SHA1 Hash" -Value ([byte[]]($thumb -split '(?<=\G..)(?=.)' | ForEach-Object { [Convert]::ToByte($_, 16) })) -Type Binary -ErrorAction SilentlyContinue
Set-ItemProperty -Path $regPath -Name "PEAP-Certificate" -Value $thumb -Force -ErrorAction SilentlyContinue

Write-Host "[5] Ajout clients RADIUS..."
netsh nps add client name="AP-IRIS" address="192.168.50.5" sharedsecret="RadiusRTR_IRIS_2026!" state=enable 2>&1 | Out-Null
netsh nps add client name="RT2-IRIS" address="192.168.50.1" sharedsecret="RadiusRTR_IRIS_2026!" state=enable 2>&1 | Out-Null
netsh nps add client name="SW2-IRIS" address="192.168.50.2" sharedsecret="RadiusSW_IRIS_2026!" state=enable 2>&1 | Out-Null
Write-Host "    3 clients ajoutés"

Write-Host "[6] CRP 802.1X..."
$time = "0 00:00-24:00; 1 00:00-24:00; 2 00:00-24:00; 3 00:00-24:00; 4 00:00-24:00; 5 00:00-24:00; 6 00:00-24:00"
netsh nps add crp name="CRP_IRIS" processingorder=1 conditionid=0x1006 conditiondata="$time" profileid=0x1025 profiledata=0x1 2>&1 | Out-Null

Write-Host "[7] Politiques réseau avec VLAN..."
$pols = @(
    @{Name="NP_Etudiants";    Order=10; Group="MEDIASCHOOL\GRP_Etudiants_SISR|MEDIASCHOOL\GRP_Etudiants_SLAM"; Vlan=10},
    @{Name="NP_Profs";        Order=20; Group="MEDIASCHOOL\GRP_Profs";                                          Vlan=20},
    @{Name="NP_Administration";Order=30;Group="MEDIASCHOOL\GRP_Administration";                                 Vlan=30},
    @{Name="NP_Invites";      Order=40; Group="MEDIASCHOOL\GRP_Invites";                                        Vlan=40},
    @{Name="NP_IT_Admin";     Order=50; Group="MEDIASCHOOL\GRP_IT_Admin";                                       Vlan=50}
)
foreach ($p in $pols) {
    $r = netsh nps add np name="$($p.Name)" processingorder=$($p.Order) `
        conditionid=0x1023 conditiondata="$($p.Group)" `
        profileid=0x100f profiledata=TRUE `
        profileid=0x1009 profiledata=0x5 `
        profileid=0x40 profiledata=0xd `
        profileid=0x41 profiledata=0x6 `
        profileid=0x51 profiledata="$($p.Vlan)" 2>&1
    Write-Host "    $($p.Name) VLAN $($p.Vlan): $r"
}

Write-Host "[8] Enregistrement NPS dans AD..."
netsh nps add registeredserver 2>&1 | Out-Null

Write-Host "[9] Export config de sauvegarde..."
Export-NpsConfiguration -Path "C:\NPS_Config_IRIS_$(Get-Date -Format 'yyyyMMdd_HHmm').xml" -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== ÉTAT FINAL ==="
Write-Host "IAS: $((sc.exe query IAS | Select-String 'STATE').ToString().Trim())"
Write-Host "Cert: $thumb"
netsh nps show client 2>&1 | Select-String "Name|Address"
