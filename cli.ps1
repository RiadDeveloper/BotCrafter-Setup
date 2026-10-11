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
