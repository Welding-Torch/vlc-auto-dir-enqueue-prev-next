# VLC AutoDirEnqueue Extension Installer for Windows
#
# Adapted from the VLSub OpenSubtitles.com Extension Installer script
# Source: https://github.com/opensubtitles/vlsub-opensubtitles-com
#
param( 
    [switch]$Force 
) 
 
# Set colors and encoding 
$Host.UI.RawUI.ForegroundColor = "White" 
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8 
 
Write-Host "================================================" -ForegroundColor Cyan 
Write-Host "VLC AutoDirEnqueue Extension Installer" -ForegroundColor Cyan 
Write-Host "================================================" -ForegroundColor Cyan 
Write-Host "" 
 
# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 3) {
    Write-Host "[ERROR] PowerShell 3.0 or higher is required" -ForegroundColor Red
    Write-Host "Please update PowerShell and try again." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Check execution policy
$executionPolicy = Get-ExecutionPolicy
if ($executionPolicy -eq "Restricted") {
    Write-Host "[WARNING] PowerShell execution policy is restricted" -ForegroundColor Yellow
    Write-Host "Run this command as Administrator to allow scripts:" -ForegroundColor Yellow
    Write-Host "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Cyan
    if (-not $Force) {
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# Detect VLC installation
Write-Host "Checking for VLC installation..." -ForegroundColor Blue

$vlcPaths = @(
    "${env:ProgramFiles}\\VideoLAN\\VLC\\vlc.exe",
    "${env:ProgramFiles(x86)}\\VideoLAN\\VLC\\vlc.exe",
    "${env:LOCALAPPDATA}\\Programs\\VideoLAN\\VLC\\vlc.exe"
)

$vlcFound = $false
foreach ($path in $vlcPaths) {
    if (Test-Path $path) {
        Write-Host "[OK] VLC found at: $path" -ForegroundColor Green
        $vlcFound = $true
        break
    }
}

if (-not $vlcFound) {
    Write-Host "[WARNING] VLC not found in standard locations" -ForegroundColor Yellow
    Write-Host "Download VLC: https://www.videolan.org/vlc/download-windows.html" -ForegroundColor Cyan
    if (-not $Force) {
        $continue = Read-Host "Continue installation anyway? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            exit 1
        }
    }
}

# Set installation directory
$vlcExtDir = "$env:APPDATA\\vlc\\lua\\extensions"
Write-Host "Extension directory: $vlcExtDir" -ForegroundColor Blue

# Create directory if it doesn't exist
if (-not (Test-Path $vlcExtDir)) {
    Write-Host "Creating extension directory..." -ForegroundColor Blue
    try {
        New-Item -ItemType Directory -Path $vlcExtDir -Force | Out-Null
        Write-Host "[OK] Directory created" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to create directory: $_" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
} else {
    Write-Host "[OK] Directory exists" -ForegroundColor Green
}

# Backup existing installation
$existingFile = "$vlcExtDir\\auto_dir_enqueue.lua"
if (Test-Path $existingFile) {
    Write-Host "Found existing AutoDirEnqueue installation..." -ForegroundColor Blue
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = "$existingFile.backup.$timestamp"
    try {
        Copy-Item $existingFile $backupFile
        Write-Host "[OK] Backup created: auto_dir_enqueue.lua.backup.$timestamp" -ForegroundColor Green
    } catch {
        Write-Host "[WARNING] Could not create backup: $_" -ForegroundColor Yellow
    }
}

# Download the extension
$downloadUrl = "https://raw.githubusercontent.com/Welding-Torch/vlc-auto-dir-enqueue-prev-next/main/auto_dir_enqueue.lua"
$destinationFile = "$vlcExtDir\\auto_dir_enqueue.lua"

Write-Host "Downloading AutoDirEnqueue extension..." -ForegroundColor Blue
Write-Host "From: $downloadUrl" -ForegroundColor Cyan

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $progressPreference = 'Continue'
    Invoke-WebRequest -Uri $downloadUrl -OutFile $destinationFile -UseBasicParsing
    
    Write-Host "[OK] Download successful" -ForegroundColor Green
    Write-Host "[OK] Installation complete" -ForegroundColor Green
    Write-Host "Installed to: $destinationFile" -ForegroundColor Blue
} catch {
    Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red
    Write-Host "Please check your internet connection and try again." -ForegroundColor Red
    Write-Host "Or download manually from: https://github.com/Welding-Torch/vlc-auto-dir-enqueue-prev-next" -ForegroundColor Cyan
    Read-Host "Press Enter to exit"
    exit 1
}

# Verify installation
if (Test-Path $destinationFile) {
    $fileSize = (Get-Item $destinationFile).Length
    Write-Host "[OK] File installed successfully ($([math]::Round($fileSize/1KB, 1)) KB)" -ForegroundColor Green
}

# Configure VLC interface (vlcrc)
$vlcrcPath = "$env:APPDATA\\vlc\\vlcrc"
Write-Host "Configuring VLC interface settings..." -ForegroundColor Blue

try {
    if (-not (Test-Path $vlcrcPath)) {
        Write-Host "[WARNING] vlcrc not found, creating new one..." -ForegroundColor Yellow
        New-Item -ItemType File -Path $vlcrcPath -Force | Out-Null
    }

    $vlcrcContent = Get-Content $vlcrcPath -Raw

    if ($vlcrcContent -notmatch "extraintf=luaintf") {
        Add-Content $vlcrcPath "`nextraintf=luaintf"
        Write-Host "[OK] Added extraintf=luaintf" -ForegroundColor Green
    } else {
        Write-Host "[OK] extraintf already configured" -ForegroundColor Green
    }

    if ($vlcrcContent -notmatch "lua-intf=auto_dir_enqueue") {
        Add-Content $vlcrcPath "`nlua-intf=auto_dir_enqueue"
        Write-Host "[OK] Added lua-intf=auto_dir_enqueue" -ForegroundColor Green
    } else {
        Write-Host "[OK] lua-intf already configured" -ForegroundColor Green
    }

} catch {
    Write-Host "[WARNING] Failed to update vlcrc: $_" -ForegroundColor Yellow
    Write-Host "You may need to manually add the following lines:" -ForegroundColor Yellow
    Write-Host "extraintf=luaintf" -ForegroundColor Cyan
    Write-Host "lua-intf=auto_dir_enqueue" -ForegroundColor Cyan
}

# Completion
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "INSTALLATION COMPLETE!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Extension installed to:" -ForegroundColor Blue
Write-Host "   $destinationFile" -ForegroundColor Yellow
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Restart VLC Media Player" -ForegroundColor White
Write-Host "2. Open a file in a folder that contains multiple media files" -ForegroundColor White
Write-Host "3. Use Next/Previous to verify auto-enqueue" -ForegroundColor White
Write-Host ""
Write-Host "To uninstall: Delete the file at the path shown above" -ForegroundColor Blue
Write-Host ""

if (-not $Force) {
    Read-Host "Press Enter to exit"
}
