# ==============================================================================
# BotCrafter Backend Automated Windows VPS Installer & 24/7 Autostart Setup
# Supports: Windows Server 2016/2019/2022, Windows 10/11 Pro
# ==============================================================================

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# Clear Console and display banner
Clear-Host
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "   BOTCRAFTER BACKEND ENGINE - WINDOWS VPS ONE-COMMAND AUTO-INSTALLER         " -ForegroundColor Magenta
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Detect Public IP Address
Write-Host "[*] Detecting VPS Public IP Address..." -ForegroundColor Blue
$DetectedIP = "127.0.0.1"
try {
    $DetectedIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 4).Trim()
} catch {
    try {
        $DetectedIP = (Invoke-RestMethod -Uri "https://ifconfig.me/ip" -TimeoutSec 4).Trim()
    } catch {
        $DetectedIP = "127.0.0.1"
    }
}
Write-Host "[+] Detected Public IP: $DetectedIP" -ForegroundColor Green
Write-Host ""

# 2. Interactive Prompts
Write-Host "-------------------- [ 1. Server Configuration ] --------------------" -ForegroundColor Yellow

# Port
$InputPort = Read-Host "➜ Enter Backend Port [Default: 8000]"
$Port = if ([string]::IsNullOrWhiteSpace($InputPort)) { "8000" } else { $InputPort }

# Host IP / Domain
$InputHost = Read-Host "➜ Enter Public IP or Domain [Default: $DetectedIP]"
$ServerHost = if ([string]::IsNullOrWhiteSpace($InputHost)) { $DetectedIP } else { $InputHost }

# Storage Path
$DefaultDataDir = "C:\botcrafter\instances"
$InputDataDir = Read-Host "➜ Enter Bot Instances Storage Directory [Default: $DefaultDataDir]"
$DataDir = if ([string]::IsNullOrWhiteSpace($InputDataDir)) { $DefaultDataDir } else { $InputDataDir }

Write-Host ""
Write-Host "------------------ [ 2. Supabase Cloud Database ] -------------------" -ForegroundColor Yellow

$DefaultSupabaseUrl = "https://tezvoaxbimwumdkkfles.supabase.co"
$InputSupabaseUrl = Read-Host "➜ Enter Supabase URL [Default: $DefaultSupabaseUrl]"
$SupabaseUrl = if ([string]::IsNullOrWhiteSpace($InputSupabaseUrl)) { $DefaultSupabaseUrl } else { $InputSupabaseUrl }

$DefaultAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRlenZvYXhiaW13dW1ka2tmbGVzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0NTUxMzIsImV4cCI6MjEwMzAzMTEzMn0.bOPGSr4kJARHIojxCwI9yDFc_ctF4KO7-O_Gzup-As8"
$InputAnonKey = Read-Host "➜ Enter Supabase Anon Key [Press Enter for default key]"
$SupabaseAnonKey = if ([string]::IsNullOrWhiteSpace($InputAnonKey)) { $DefaultAnonKey } else { $InputAnonKey }

$InputServiceKey = Read-Host "➜ Enter Supabase Service Role Key (optional, press Enter to skip)"
$SupabaseServiceKey = if ([string]::IsNullOrWhiteSpace($InputServiceKey)) { "" } else { $InputServiceKey }

Write-Host ""
Write-Host "--------------------- [ 3. Administrator Setup ] --------------------" -ForegroundColor Yellow

do {
    $AdminEmail = Read-Host "➜ Enter Admin Email Address"
} while ([string]::IsNullOrWhiteSpace($AdminEmail))

do {
    $AdminPassword = Read-Host -Prompt "➜ Enter Admin Password"
} while ([string]::IsNullOrWhiteSpace($AdminPassword))

Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "[+] Configuration collected successfully! Setting up Windows engine..." -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

# 3. Setup Directories
$InstallDir = "C:\botcrafter"
$BinaryDest = "$InstallDir\botcrafter-server.exe"
$ConfigFile = "$InstallDir\botcrafter.env"

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
}

# 4. Download Standalone Compiled Binary (Zero Source Code Exposed)
Write-Host "[*] Acquiring compiled BotCrafter executable..." -ForegroundColor Blue
$LocalBinary = "$PSScriptRoot\backend\dist\botcrafter-server.exe"

if (Test-Path $LocalBinary) {
    Write-Host "[+] Installing local pre-compiled binary..." -ForegroundColor Green
    Copy-Item -Path $LocalBinary -Destination $BinaryDest -Force
} else {
    $DownloadUrl = if ($env:BOTCRAFTER_BINARY_URL) { $env:BOTCRAFTER_BINARY_URL } else { "https://github.com/RiadDeveloper/BotCrafter-Setup/releases/latest/download/botcrafter-server.exe" }
    Write-Host "[*] Downloading protected binary from: $DownloadUrl" -ForegroundColor Cyan
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $BinaryDest -UseBasicParsing
        Write-Host "[+] Binary downloaded successfully!" -ForegroundColor Green
    } catch {
        Write-Host "[!] Could not download from release URL ($($_.Exception.Message))." -ForegroundColor Yellow
        Write-Host "[*] Checking for local repository to compile on-the-fly..." -ForegroundColor Blue
        
        $RepoPath = "$InstallDir\repo"
        if (-not (Test-Path "$RepoPath\.git")) {
            git clone --depth 1 https://github.com/RiadDeveloper/BotCrafter.git $RepoPath
        }
        
        Write-Host "[*] Compiling binary on Windows VPS..." -ForegroundColor Blue
        Set-Location "$RepoPath\backend"
        python -m pip install -r requirements.txt pyinstaller
        python -m PyInstaller --clean --noconfirm botcrafter.spec
        Copy-Item -Path "$RepoPath\backend\dist\botcrafter-server.exe" -Destination $BinaryDest -Force
        
        # Purge source code after compilation to protect IP
        Remove-Item -Path $RepoPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[+] Source code purged. Protected binary ready at $BinaryDest" -ForegroundColor Green
    }
}

# 5. Write Environment Configuration File
Write-Host "[*] Writing configuration to $ConfigFile..." -ForegroundColor Blue
$EnvContent = @"
PROJECT_NAME="BotCrafter Engine"
ENVIRONMENT="production"
HOST="0.0.0.0"
PORT=$Port
SERVER_HOST_IP="$ServerHost"
SERVER_DOMAIN="$ServerHost"
DATA_DIR="$DataDir"
SUPABASE_URL="$SupabaseUrl"
SUPABASE_ANON_KEY="$SupabaseAnonKey"
SUPABASE_SERVICE_ROLE_KEY="$SupabaseServiceKey"
ADMIN_EMAIL="$AdminEmail"
ADMIN_PASSWORD="$AdminPassword"
CORS_ORIGINS="*"
"@

[System.IO.File]::WriteAllText($ConfigFile, $EnvContent, [System.Text.Encoding]::UTF8)

# 6. Configure Windows Defender Firewall (Open Port)
Write-Host "[*] Configuring Windows Defender Firewall for TCP Port $Port..." -ForegroundColor Blue
try {
    Remove-NetFirewallRule -DisplayName "BotCrafter Backend Port $Port" -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "BotCrafter Backend Port $Port" -Direction Inbound -LocalPort $Port -Protocol TCP -Action Allow -Force | Out-Null
    Write-Host "[+] Firewall rule configured successfully." -ForegroundColor Green
} catch {
    Write-Host "[!] Warning while setting firewall rule: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 7. Create Windows 24/7 Autostart Service via Scheduled Task (Reboot & Crash Proof)
Write-Host "[*] Configuring Windows 24/7 Autostart Service (Task Scheduler)..." -ForegroundColor Blue

# Create startup launcher batch script to load environment variables and launch binary
$LauncherBat = "$InstallDir\run-botcrafter.cmd"
$BatContent = @"
@echo off
cd /d "$InstallDir"
for /f "usebackq tokens=1,* delims==" %%A in ("$ConfigFile") do (
    set "%%A=%%B"
)
"$BinaryDest"
"@
[System.IO.File]::WriteAllText($LauncherBat, $BatContent, [System.Text.Encoding]::ASCII)

$TaskName = "BotCrafterServer"
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$Action = New-ScheduledTaskAction -Execute "$LauncherBat" -WorkingDirectory "$InstallDir"
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Days 365)

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -User "SYSTEM" -RunLevel Highest -Force | Out-Null

# Start the task immediately
Start-ScheduledTask -TaskName $TaskName
Write-Host "[+] Windows 24/7 Service started successfully!" -ForegroundColor Green

# 8. Create Global CLI Helper: 'botcrafter'
$CliBat = "C:\Windows\System32\botcrafter.cmd"
$CliContent = @"
@echo off
if "%1"=="" goto help
if "%1"=="start" (
    schtasks /run /tn "BotCrafterServer"
    echo [*] Started BotCrafter service.
    goto end
)
if "%1"=="stop" (
    taskkill /F /IM botcrafter-server.exe >nul 2>&1
    echo [*] Stopped BotCrafter service.
    goto end
)
if "%1"=="restart" (
    taskkill /F /IM botcrafter-server.exe >nul 2>&1
    schtasks /run /tn "BotCrafterServer"
    echo [*] Restarted BotCrafter service.
    goto end
)
if "%1"=="status" (
    tasklist /FI "IMAGENAME eq botcrafter-server.exe"
    schtasks /query /tn "BotCrafterServer"
    goto end
)
if "%1"=="info" (
    echo ==========================================
    echo BotCrafter Windows Service Information
    echo ==========================================
    echo Server URL: http://$ServerHost:$Port
    echo API Docs:   http://$ServerHost:$Port/docs
    echo Storage:    $DataDir
    echo Binary:     $BinaryDest
    echo Config:     $ConfigFile
    echo ==========================================
    goto end
)
:help
echo BotCrafter CLI Manager for Windows
echo Usage: botcrafter [start ^| stop ^| restart ^| status ^| info]
:end
"@
try {
    [System.IO.File]::WriteAllText($CliBat, $CliContent, [System.Text.Encoding]::ASCII)
} catch {}

# 9. Final Output
Start-Sleep -Seconds 3
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host "   🎉 CONGRATULATIONS! BOTCRAFTER IS INSTALLED ON WINDOWS & RUNNING 24/7! 🎉" -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  🌐 Live Server URL:       http://$ServerHost:$Port" -ForegroundColor Cyan
Write-Host "  📚 Interactive API Docs:  http://$ServerHost:$Port/docs" -ForegroundColor Cyan
Write-Host "  👤 Administrator Email:   $AdminEmail" -ForegroundColor Yellow
Write-Host "  💾 Storage Path:          $DataDir" -ForegroundColor Yellow
Write-Host "  🔄 Windows Autostart:     ENABLED (Starts automatically on VPS boot 24/7)" -ForegroundColor Green
Write-Host ""
Write-Host "-------------------- [ Management CLI Commands ] --------------------" -ForegroundColor Magenta
Write-Host "  ➜ Check service status:   botcrafter status" -ForegroundColor Cyan
Write-Host "  ➜ Restart backend:        botcrafter restart" -ForegroundColor Cyan
Write-Host "  ➜ Stop backend:           botcrafter stop" -ForegroundColor Cyan
Write-Host "  ➜ Start backend:          botcrafter start" -ForegroundColor Cyan
Write-Host "  ➜ View server info:       botcrafter info" -ForegroundColor Cyan
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
