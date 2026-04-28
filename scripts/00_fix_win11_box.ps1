# Fix Windows 11 OVF compatibility for VirtualBox 7.1.x
# ResourceType 32768 (NVMe controller) is not supported by VirtualBox 7.1.x
# This script downloads the box if absent and patches the OVF file

$ErrorActionPreference = "Stop"

$boxName    = "gusztavvargadr/windows-11-23h2-enterprise"
$boxVersion = "2509.0.0"
$boxSlug    = "gusztavvargadr-VAGRANTSLASH-windows-11-23h2-enterprise"
$boxOvf     = "$env:USERPROFILE\.vagrant.d\boxes\$boxSlug\$boxVersion\amd64\virtualbox\box.ovf"

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "  [PRE-UP] Checking Windows 11 box (VirtualBox 7.1 fix)" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

# Step 1: Download box if not present
if (-not (Test-Path $boxOvf)) {
    Write-Host "[INFO] Box '$boxName' v$boxVersion not found - downloading..." -ForegroundColor Yellow
    Write-Host "[INFO] This may take 30-60 minutes depending on your connection." -ForegroundColor Yellow
    Write-Host ""

    $proc = Start-Process -FilePath "vagrant" `
        -ArgumentList "box add `"$boxName`" --box-version `"$boxVersion`" --provider virtualbox --no-tty" `
        -Wait -PassThru -NoNewWindow

    if ($proc.ExitCode -ne 0) {
        Write-Host "[ERROR] Failed to download box. Check your connection." -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] Box downloaded." -ForegroundColor Green
} else {
    Write-Host "[OK] Box already present." -ForegroundColor Green
}

# Verify OVF exists after download
if (-not (Test-Path $boxOvf)) {
    Write-Host "[ERROR] OVF not found after download: $boxOvf" -ForegroundColor Red
    exit 1
}

$content = [System.IO.File]::ReadAllText($boxOvf)

if ($content -notmatch '<rasd:ResourceType>32768</rasd:ResourceType>') {
    Write-Host "[OK] OVF already compatible, no patch needed." -ForegroundColor Green
    exit 0
}

Write-Host "[PATCH] Removing NVMe controller (ResourceType 32768)..." -ForegroundColor Yellow

# Remove <Item> block containing ResourceType 32768
$patched = [regex]::Replace(
    $content,
    '(?s)\s*<Item>\s*(?:(?!</Item>).)*<rasd:ResourceType>32768</rasd:ResourceType>(?:(?!</Item>).)*</Item>',
    ''
)

if ($patched -eq $content) {
    # Fallback: line-by-line approach
    $lines = $content -split "`n"
    $output = [System.Collections.Generic.List[string]]::new()
    $inBlock = $false
    $blockBuffer = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $lines) {
        if ($line -match '<Item>') {
            $inBlock = $true
            $blockBuffer.Clear()
        }
        if ($inBlock) {
            $blockBuffer.Add($line)
            if ($line -match '</Item>') {
                $inBlock = $false
                $blockStr = $blockBuffer -join "`n"
                if ($blockStr -notmatch '<rasd:ResourceType>32768</rasd:ResourceType>') {
                    $output.AddRange($blockBuffer)
                }
                $blockBuffer.Clear()
            }
        } else {
            $output.Add($line)
        }
    }
    $patched = $output -join "`n"
}

[System.IO.File]::WriteAllText($boxOvf, $patched, [System.Text.Encoding]::UTF8)

# Verify patch
if ([System.IO.File]::ReadAllText($boxOvf) -notmatch '<rasd:ResourceType>32768</rasd:ResourceType>') {
    Write-Host "[OK] OVF patched successfully! VirtualBox 7.1 can now import the VM." -ForegroundColor Green
} else {
    Write-Host "[ERROR] Patch failed - ResourceType 32768 still present" -ForegroundColor Red
    exit 1
}

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "  [PRE-UP] Done - starting VM..." -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""