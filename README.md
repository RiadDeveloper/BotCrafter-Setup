# 🚀 BotCrafter - One-Command VPS Installer (24/7 Engine)

Official public deployment repository for **BotCrafter Engine**.  
This repository contains the automated one-command installers for both **Linux VPS** and **Windows VPS**.

> [!NOTE]
> All installations download pre-compiled, standalone native binaries. **Zero proprietary Python source code is exposed.**

---

## ⚡ Quick Start: One-Command Installation

### 🐧 1. For Linux VPS (Ubuntu, Debian, CentOS, AlmaLinux, Rocky Linux)
Connect to your VPS via SSH as **root** (or `sudo`) and run:

```bash
curl -fsSL https://raw.githubusercontent.com/RiadDeveloper/BotCrafter-Setup/main/install.sh | sudo bash
```

---

### 🪟 2. For Windows VPS (Windows Server 2016/2019/2022, Windows 10/11)
Open **PowerShell as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/RiadDeveloper/BotCrafter-Setup/main/install.ps1 | iex
```

---

## 🛠️ What the Installer Does

1. **Interactive Questionnaire**:
   * Asks for Backend Port (Default: `8000`)
   * Asks for Server Public IP or Domain (Auto-detected)
   * Asks for Supabase Database Credentials
   * Asks for Administrator Email & Password
   * Sets up Bot Persistent Storage Directory
2. **🔒 Zero Source Code Exposure**:
   * Downloads pre-compiled native executable binary (`botcrafter-server`).
   * No `.py` source files or private repositories are ever exposed on the client machine.
3. **🔄 24/7 Uptime & Reboot Persistence**:
   * **Linux:** Configured via `systemd` (`Restart=always`).
   * **Windows:** Configured via Windows Task Scheduler (`AtStartup` under `SYSTEM`).
   * **Reboot Proof:** Automatically starts on VPS boot and recovers all previously running bots without manual intervention.
4. **🌐 Instant Server URL**:
   * Prints the live server URL (`http://<VPS_IP>:<PORT>`) and Swagger API Docs (`http://<VPS_IP>:<PORT>/docs`) upon completion.

---

## 🎛️ Management CLI (`botcrafter`)

After installation, manage your server from any terminal on the VPS:

| Command | Action |
|---|---|
| `botcrafter status` | Check service health, process status, and uptime |
| `botcrafter logs` | View live backend logs in real-time (Linux) |
| `botcrafter restart` | Gracefully restart the backend engine |
| `botcrafter stop` | Stop the backend engine |
| `botcrafter start` | Start the backend engine |
| `botcrafter info` | View server URL, port, storage, and admin email |

---

## 🔗 Connect Your Frontend

Set these environment variables in your Next.js frontend (Vercel or custom domain):

```env
NEXT_PUBLIC_API_URL=http://<YOUR_VPS_IP>:<PORT>
NEXT_PUBLIC_WS_URL=ws://<YOUR_VPS_IP>:<PORT>
```
