# ==============================================================================
# BotCrafter Backend Automated Windows VPS Installer & 24/7 Autostart Setup
# Supports: Windows Server 2016/2019/2022, Windows 10/11 Pro
# ==============================================================================

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Error: Administrator privileges required!" -ForegroundColor Red
    Write-Host "    Please right-click PowerShell -> 'Run as Administrator', then run this command again." -ForegroundColor Yellow
    return
}

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
$DefaultDataDir = "C:/botcrafter/instances"
$InputDataDir = Read-Host "➜ Enter Bot Instances Storage Directory [Default: $DefaultDataDir]"
$DataDir = if ([string]::IsNullOrWhiteSpace($InputDataDir)) { $DefaultDataDir } else { $InputDataDir }
$DataDirClean = $DataDir.Replace('\', '/')

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
$EnvFile = "$InstallDir\.env"

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
}

# 4. Download Standalone Compiled Binary (Zero Source Code Exposed)
Write-Host "[*] Stopping any active BotCrafter processes to release file locks..." -ForegroundColor Cyan
Stop-Process -Name "botcrafter-server" -Force -ErrorAction SilentlyContinue
Stop-ScheduledTask -TaskName "BotCrafterServer" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "[*] Acquiring compiled BotCrafter executable..." -ForegroundColor Blue
$LocalBinary = "$PSScriptRoot\backend\dist\botcrafter-server.exe"

if (Test-Path $LocalBinary) {
    Write-Host "[+] Installing local pre-compiled binary..." -ForegroundColor Green
    Stop-Process -Name "botcrafter-server" -Force -ErrorAction SilentlyContinue
    Copy-Item -Path $LocalBinary -Destination $BinaryDest -Force
} else {
    $DownloadUrl = if ($env:BOTCRAFTER_BINARY_URL) { $env:BOTCRAFTER_BINARY_URL } else { "https://github.com/RiadDeveloper/BotCrafter-Setup/releases/latest/download/botcrafter-server.exe" }
    Write-Host "[*] Downloading protected binary from: $DownloadUrl" -ForegroundColor Cyan
    $TempBinary = "$InstallDir\botcrafter-server.tmp.exe"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempBinary -UseBasicParsing
        Stop-Process -Name "botcrafter-server" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Move-Item -Path $TempBinary -Destination $BinaryDest -Force
        Write-Host "[+] Binary downloaded and installed successfully!" -ForegroundColor Green
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
        
        Stop-Process -Name "botcrafter-server" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Move-Item -Path "$RepoPath\backend\dist\botcrafter-server.exe" -Destination $BinaryDest -Force
        
        # Purge source code after compilation to protect IP
        Set-Location "$InstallDir"
        Remove-Item -Path $RepoPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[+] Source code purged. Protected binary ready at $BinaryDest" -ForegroundColor Green
    }
}

# 5. Write Environment Configuration File
Write-Host "[*] Writing configuration to $ConfigFile and $EnvFile..." -ForegroundColor Blue
$EnvContent = @"
PROJECT_NAME="BotCrafter Engine"
ENVIRONMENT="production"
HOST="0.0.0.0"
PORT=$Port
SERVER_HOST_IP="$ServerHost"
SERVER_DOMAIN="$ServerHost"
DATA_DIR="$DataDirClean"
SUPABASE_URL="$SupabaseUrl"
SUPABASE_ANON_KEY="$SupabaseAnonKey"
SUPABASE_SERVICE_ROLE_KEY="$SupabaseServiceKey"
ADMIN_EMAIL="$AdminEmail"
ADMIN_PASSWORD="$AdminPassword"
CORS_ORIGINS="*"
"@

[System.IO.File]::WriteAllText($ConfigFile, $EnvContent, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($EnvFile, $EnvContent, [System.Text.Encoding]::UTF8)

# 6. Configure Windows Defender Firewall (Open Port)
Write-Host "[*] Configuring Windows Defender Firewall for TCP Port $Port..." -ForegroundColor Blue
try {
    Remove-NetFirewallRule -DisplayName "BotCrafter Backend Port $Port" -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "BotCrafter Backend Port $Port" -Direction Inbound -LocalPort $Port -Protocol TCP -Action Allow | Out-Null
    Write-Host "[+] Firewall rule configured successfully." -ForegroundColor Green
} catch {
    Write-Host "[!] Warning while setting firewall rule: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 7. Create Windows 24/7 Autostart Service via Scheduled Task (Reboot & Crash Proof)
Write-Host "[*] Configuring Windows 24/7 Autostart Service (Task Scheduler)..." -ForegroundColor Blue

# Create startup launcher batch script to launch binary directly
$LauncherBat = "$InstallDir\run-botcrafter.cmd"
$BatContent = @"
@echo off
cd /d "$InstallDir"
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
$CliPs1Path = "$InstallDir\cli.ps1"
$LocalCli = "$InstallDir\botcrafter.cmd"
$CliBat = "C:\Windows\System32\botcrafter.cmd"

$CliPs1Content = @'
param(
    [string]$Command = "help",
    [string]$Arg1 = ""
)

$InstallDir = "C:\botcrafter"
$EnvFile = "$InstallDir\.env"
$EnvFile2 = "$InstallDir\botcrafter.env"
$Binary = "$InstallDir\botcrafter-server.exe"
$TaskName = "BotCrafterServer"

switch ($Command.ToLower()) {
    "start" {
        Write-Host "[*] Starting BotCrafter Windows Service..." -ForegroundColor Cyan
        schtasks /run /tn $TaskName | Out-Null
        Start-Sleep -Seconds 1
        $proc = Get-Process -Name "botcrafter-server" -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "[+] BotCrafter service started successfully (PID: $($proc.Id))!" -ForegroundColor Green
        } else {
            Write-Host "[!] Service triggered via Task Scheduler." -ForegroundColor Yellow
        }
    }
    "stop" {
        Write-Host "[*] Stopping BotCrafter Engine..." -ForegroundColor Cyan
        Stop-Process -Name "botcrafter-server" -Force -ErrorAction SilentlyContinue
        Write-Host "[+] BotCrafter service stopped." -ForegroundColor Green
    }
    "restart" {
        Write-Host "[*] Restarting BotCrafter Engine..." -ForegroundColor Cyan
        Stop-Process -Name "botcrafter-server" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        schtasks /run /tn $TaskName | Out-Null
        Start-Sleep -Seconds 2
        $proc = Get-Process -Name "botcrafter-server" -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "[+] BotCrafter restarted successfully (PID: $($proc.Id))!" -ForegroundColor Green
        } else {
            Write-Host "[+] Restart signal sent." -ForegroundColor Green
        }
    }
    "status" {
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "   BotCrafter Windows Service Status      " -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        $proc = Get-Process -Name "botcrafter-server" -ErrorAction SilentlyContinue
        if ($proc) {
            $mem = [math]::Round((($proc | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB), 2)
            $pids = ($proc | ForEach-Object { $_.Id }) -join ", "
            Write-Host "Process Status:   RUNNING" -ForegroundColor Green
            Write-Host "Process ID:       $pids"
            Write-Host "Memory Usage:     $mem MB"
        } else {
            Write-Host "Process Status:   STOPPED" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "Scheduled Task Status:" -ForegroundColor Yellow
        schtasks /query /tn $TaskName /fo LIST 2>$null | Select-String "TaskName|Status|Next Run Time|Last Run Time|Last Result"
    }
    "info" {
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "   BotCrafter Configuration Details       " -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        $targetEnv = if (Test-Path $EnvFile) { $EnvFile } else { $EnvFile2 }
        if (Test-Path $targetEnv) {
            $raw = Get-Content $targetEnv -Raw
            $ip = "127.0.0.1"
            $port = "8000"
            $admin = "N/A"
            $data = "$InstallDir\instances"
            
            $mIp = [regex]::Match($raw, 'SERVER_HOST_IP="?([^"\r\n]+)"?')
            if ($mIp.Success) { $ip = $mIp.Groups[1].Value }
            $mPort = [regex]::Match($raw, 'PORT=(\d+)')
            if ($mPort.Success) { $port = $mPort.Groups[1].Value }
            $mAdmin = [regex]::Match($raw, 'ADMIN_EMAIL="?([^"\r\n]+)"?')
            if ($mAdmin.Success) { $admin = $mAdmin.Groups[1].Value }
            $mData = [regex]::Match($raw, 'DATA_DIR="?([^"\r\n]+)"?')
            if ($mData.Success) { $data = $mData.Groups[1].Value }

            $proc = Get-Process -Name "botcrafter-server" -ErrorAction SilentlyContinue
            $statusText = if ($proc) { "ONLINE (PID: $($proc.Id))" } else { "OFFLINE" }

            Write-Host "Service Status:  $statusText" -ForegroundColor $(if ($proc) { "Green" } else { "Red" })
            Write-Host "Live Server URL: http://${ip}:${port}" -ForegroundColor Cyan
            Write-Host "API Docs:        http://${ip}:${port}/docs" -ForegroundColor Cyan
            Write-Host "Storage Path:    $data" -ForegroundColor Yellow
            Write-Host "Admin Email:     $admin" -ForegroundColor Yellow
            Write-Host "Executable:      $Binary"
            Write-Host "Config File:     $targetEnv"
        } else {
            Write-Host "[!] Configuration file not found at $EnvFile" -ForegroundColor Red
        }
        Write-Host "==========================================" -ForegroundColor Cyan
    }
    "update" {
        Write-Host "==============================================================================" -ForegroundColor Green
        Write-Host " [*] Updating BotCrafter Engine to Latest Release (Zero Data Loss)..." -ForegroundColor Green
        Write-Host "==============================================================================" -ForegroundColor Green
        
        $url = "https://github.com/RiadDeveloper/BotCrafter-Setup/releases/latest/download/botcrafter-server.exe"
        $tempDest = "$InstallDir\botcrafter-server.new.exe"
        
        Write-Host "[*] Downloading latest binary release from GitHub..." -ForegroundColor Cyan
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $url -OutFile $tempDest -UseBasicParsing
            
            Write-Host "[*] Stopping current engine process..." -ForegroundColor Cyan
            Stop-Process -Name "botcrafter-server" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            
            Move-Item -Path $tempDest -Destination $Binary -Force
            schtasks /run /tn $TaskName | Out-Null
            Start-Sleep -Seconds 2
            
            Write-Host ""
            Write-Host "[+] BotCrafter Engine successfully updated to latest version!" -ForegroundColor Green
            Write-Host "[+] ZERO DATA LOSS: All bot instances, SQLite database, and configurations remain 100% intact!" -ForegroundColor Green
            Write-Host "[*] Background Windows service restarted 24/7." -ForegroundColor Cyan
        } catch {
            Write-Host "[!] Update failed: $($_.Exception.Message)" -ForegroundColor Red
            if (Test-Path $tempDest) { Remove-Item $tempDest -Force -ErrorAction SilentlyContinue }
        }
    }
    "set-ip" {
        $newIp = $Arg1
        if ([string]::IsNullOrWhiteSpace($newIp)) {
            $newIp = Read-Host "Enter new Server Public IP or Domain"
        }
        if ([string]::IsNullOrWhiteSpace($newIp)) {
            Write-Host "[!] IP / Domain cannot be empty." -ForegroundColor Red
            return
        }
        
        $filesToUpdate = @($EnvFile, $EnvFile2)
        $updated = $false
        $port = "8000"
        
        foreach ($f in $filesToUpdate) {
            if (Test-Path $f) {
                $raw = Get-Content $f -Raw
                $mPort = [regex]::Match($raw, 'PORT=(\d+)')
                if ($mPort.Success) { $port = $mPort.Groups[1].Value }
                
                $quotedIp = '"{0}"' -f $newIp
                $newContent = $raw -replace 'SERVER_HOST_IP="?[^"\r\n]*"?', "SERVER_HOST_IP=$quotedIp"
                $newContent = $newContent -replace 'SERVER_DOMAIN="?[^"\r\n]*"?', "SERVER_DOMAIN=$quotedIp"
                Set-Content -Path $f -Value $newContent -NoNewline
                $updated = $true
            }
        }
        
        if ($updated) {
            Write-Host "[*] Restarting BotCrafter to apply new network settings..." -ForegroundColor Cyan
            Stop-Process -Name "botcrafter-server" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            schtasks /run /tn $TaskName | Out-Null
            Start-Sleep -Seconds 2
            
            Write-Host ""
            Write-Host "[+] Server IP / Domain successfully updated to: $newIp" -ForegroundColor Green
            Write-Host "  Live Server URL: http://${newIp}:${port}" -ForegroundColor Cyan
            Write-Host "  API Docs:        http://${newIp}:${port}/docs" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  Note: Update your Frontend NEXT_PUBLIC_API_URL and NEXT_PUBLIC_WS_URL accordingly." -ForegroundColor Yellow
        } else {
            Write-Host "[!] Configuration files not found." -ForegroundColor Red
        }
    }
    "uninstall" {
        Write-Host "==============================================================================" -ForegroundColor Red
        Write-Host " [!] WARNING: You are about to UNINSTALL BotCrafter from this system!" -ForegroundColor Red
        Write-Host "==============================================================================" -ForegroundColor Red
        $ans = Read-Host "Are you sure you want to completely uninstall BotCrafter? (y/N)"
        if ($ans -notmatch "^[Yy]$") {
            Write-Host "[*] Uninstallation cancelled." -ForegroundColor Yellow
            return
        }
        
        Write-Host "[*] Stopping running processes..." -ForegroundColor Cyan
        Stop-Process -Name "botcrafter-server" -Force -ErrorAction SilentlyContinue
        
        Write-Host "[*] Removing 24/7 Scheduled Task..." -ForegroundColor Cyan
        schtasks /delete /tn $TaskName /f 2>$null | Out-Null
        
        Write-Host "[*] Removing Windows Firewall Rules..." -ForegroundColor Cyan
        Remove-NetFirewallRule -DisplayName "BotCrafter Backend Port*" -ErrorAction SilentlyContinue
        
        $delData = Read-Host "Do you also want to permanently delete all bot instance data in $InstallDir\instances? (y/N)"
        if ($delData -match "^[Yy]$") {
            Write-Host "[*] Removing entire directory: $InstallDir..." -ForegroundColor Cyan
            Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "[+] All bot instances, configs, and directory completely wiped." -ForegroundColor Green
        } else {
            Write-Host "[*] Removing binaries and service files only..." -ForegroundColor Cyan
            Remove-Item -Path "$InstallDir\botcrafter-server.exe", "$InstallDir\run-botcrafter.cmd", "$InstallDir\cli.ps1", "$InstallDir\botcrafter.cmd" -Force -ErrorAction SilentlyContinue
            Write-Host "[!] Engine removed. Bot data preserved in $InstallDir\instances." -ForegroundColor Yellow
        }
        
        Remove-Item -Path "C:\Windows\System32\botcrafter.cmd" -Force -ErrorAction SilentlyContinue
        $mPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($mPath -like "*$InstallDir*") {
            [Environment]::SetEnvironmentVariable("Path", ($mPath -replace ";?$([regex]::Escape($InstallDir))", ""), "Machine")
        }
        
        Write-Host ""
        Write-Host "[+] BotCrafter has been completely and permanently uninstalled!" -ForegroundColor Green
    }
    default {
        Write-Host "BotCrafter Windows Management CLI" -ForegroundColor Green
        Write-Host ""
        Write-Host "Usage: botcrafter [command]"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  status      Check service health and running processes"
        Write-Host "  start       Start the background engine"
        Write-Host "  stop        Stop the background engine"
        Write-Host "  restart     Restart the background engine"
        Write-Host "  update      Update engine to latest release without losing any bot data"
        Write-Host "  set-ip      Change public IP / domain and apply changes immediately"
        Write-Host "  info        Display current URLs, ports, and configuration details"
        Write-Host "  uninstall   Completely remove service, firewall rules, and files"
        Write-Host ""
    }
}
'@

try {
    [System.IO.File]::WriteAllText($CliPs1Path, $CliPs1Content, [System.Text.Encoding]::UTF8)
    
    $LocalCmdContent = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0cli.ps1`" %*"
    [System.IO.File]::WriteAllText($LocalCli, $LocalCmdContent, [System.Text.Encoding]::ASCII)
    
    $Sys32CmdContent = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\cli.ps1`" %*"
    [System.IO.File]::WriteAllText($CliBat, $Sys32CmdContent, [System.Text.Encoding]::ASCII)
} catch {}

try {
    $MachinePath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
    if ($MachinePath -notlike "*$InstallDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$MachinePath;$InstallDir", [EnvironmentVariableTarget]::Machine)
    }
} catch {}


# 9. Final Output
Start-Sleep -Seconds 3
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host "   *** CONGRATULATIONS! BOTCRAFTER IS INSTALLED ON WINDOWS & RUNNING 24/7! ***" -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Live Server URL:       http://${ServerHost}:${Port}" -ForegroundColor Cyan
Write-Host "  Interactive API Docs:  http://${ServerHost}:${Port}/docs" -ForegroundColor Cyan
Write-Host "  Administrator Email:   $AdminEmail" -ForegroundColor Yellow
Write-Host "  Storage Path:          $DataDir" -ForegroundColor Yellow
Write-Host "  Windows Autostart:     ENABLED (Starts automatically on VPS boot 24/7)" -ForegroundColor Green
Write-Host ""
Write-Host "-------------------- [ Management CLI Commands ] --------------------" -ForegroundColor Magenta
Write-Host "  -> Check service status:   botcrafter status" -ForegroundColor Cyan
Write-Host "  -> Restart backend:        botcrafter restart" -ForegroundColor Cyan
Write-Host "  -> Stop backend:           botcrafter stop" -ForegroundColor Cyan
Write-Host "  -> Start backend:          botcrafter start" -ForegroundColor Cyan
Write-Host "  -> View server info:       botcrafter info" -ForegroundColor Cyan
Write-Host "  -> Update engine (No loss):botcrafter update" -ForegroundColor Cyan
Write-Host "  -> Change server IP:       botcrafter set-ip [new_ip]" -ForegroundColor Cyan
Write-Host "  -> Uninstall BotCrafter:   botcrafter uninstall" -ForegroundColor Cyan
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
