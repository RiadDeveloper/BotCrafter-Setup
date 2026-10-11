#!/usr/bin/env bash
# ==============================================================================
# BotCrafter Backend Automated VPS Installer & Systemd Daemon Setup
# Supports: Ubuntu 20.04+, Debian 11+, CentOS 8+, AlmaLinux, Rocky Linux
# ==============================================================================

set -e

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[✗] Error: Please run this installer as root (or use: sudo bash install.sh)${NC}"
  exit 1
fi

clear
echo -e "${CYAN}"
echo "██████╗  ██████╗ ████████╗ ██████╗██████╗  █████╗ ███████╗████████╗███████╗██████╗ "
echo "██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗"
echo "██████╔╝██║   ██║   ██║   ██║     ██████╔╝███████║█████╗     ██║   █████╗  ██████╔╝"
echo "██╔══██╗██║   ██║   ██║   ██║     ██╔══██╗██╔══██║██╔══╝     ██║   ██╔══╝  ██╔══██╗"
echo "██████╔╝╚██████╔╝   ██║   ╚██████╗██║  ██║██║  ██║██║        ██║   ███████╗██║  ██║"
echo "╚═════╝  ╚═════╝    ╚═╝    ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝   ╚══════╝╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "${BOLD}${MAGENTA}   🚀 High-Performance Multi-Tenant Bot Engine - One-Command Installer${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

# 1. Detect Host Public IP
echo -e "${BLUE}[*] Detecting VPS Public IP Address...${NC}"
DETECTED_IP=$(curl -4 -s --max-time 4 https://api.ipify.org 2>/dev/null || curl -4 -s --max-time 4 https://ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
if [ -z "$DETECTED_IP" ]; then
  DETECTED_IP="127.0.0.1"
fi
echo -e "${GREEN}[✓] Detected Public IP: ${BOLD}${DETECTED_IP}${NC}"
echo ""

# 2. Interactive Questionnaire
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━ [ 1. Server Configuration ] ━━━━━━━━━━━━━━━━━━━━${NC}"

# Port Prompt
read -p "$(echo -e "${CYAN}➜ Enter Backend Port [Default: 8000]: ${NC}")" INPUT_PORT
PORT=${INPUT_PORT:-8000}

# Host / Domain Prompt
read -p "$(echo -e "${CYAN}➜ Enter Server Public IP or Domain [Default: ${DETECTED_IP}]: ${NC}")" INPUT_HOST
SERVER_HOST=${INPUT_HOST:-$DETECTED_IP}

# Data Storage Path Prompt
read -p "$(echo -e "${CYAN}➜ Enter Persistent Bot Storage Path [Default: /var/lib/botcrafter/instances]: ${NC}")" INPUT_DATA_DIR
DATA_DIR=${INPUT_DATA_DIR:-/var/lib/botcrafter/instances}

echo ""
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━ [ 2. Supabase Cloud Database ] ━━━━━━━━━━━━━━━━━━${NC}"

# Supabase URL Prompt
DEFAULT_SUPABASE_URL="https://tezvoaxbimwumdkkfles.supabase.co"
read -p "$(echo -e "${CYAN}➜ Enter Supabase URL [Default: ${DEFAULT_SUPABASE_URL}]: ${NC}")" INPUT_SUPABASE_URL
SUPABASE_URL=${INPUT_SUPABASE_URL:-$DEFAULT_SUPABASE_URL}

# Supabase Anon Key Prompt
DEFAULT_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRlenZvYXhiaW13dW1ka2tmbGVzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0NTUxMzIsImV4cCI6MjEwMzAzMTEzMn0.bOPGSr4kJARHIojxCwI9yDFc_ctF4KO7-O_Gzup-As8"
read -p "$(echo -e "${CYAN}➜ Enter Supabase Anon Key [Press Enter for default project key]: ${NC}")" INPUT_ANON_KEY
SUPABASE_ANON_KEY=${INPUT_ANON_KEY:-$DEFAULT_ANON_KEY}

# Supabase Service Role Key Prompt
read -p "$(echo -e "${CYAN}➜ Enter Supabase Service Role Key (optional, press Enter to skip): ${NC}")" INPUT_SERVICE_KEY
SUPABASE_SERVICE_ROLE_KEY=${INPUT_SERVICE_KEY:-""}

echo ""
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━ [ 3. Administrator Setup ] ━━━━━━━━━━━━━━━━━━━━${NC}"

# Admin Email Prompt
read -p "$(echo -e "${CYAN}➜ Enter Admin Email Address: ${NC}")" ADMIN_EMAIL
while [ -z "$ADMIN_EMAIL" ]; do
  echo -e "${RED}[!] Admin email cannot be empty.${NC}"
  read -p "$(echo -e "${CYAN}➜ Enter Admin Email Address: ${NC}")" ADMIN_EMAIL
done

# Admin Password Prompt
read -s -p "$(echo -e "${CYAN}➜ Enter Admin Password: ${NC}")" ADMIN_PASSWORD
echo ""
while [ -z "$ADMIN_PASSWORD" ]; do
  echo -e "${RED}[!] Admin password cannot be empty.${NC}"
  read -s -p "$(echo -e "${CYAN}➜ Enter Admin Password: ${NC}")" ADMIN_PASSWORD
  echo ""
done

echo ""
echo -e "${BLUE}==============================================================================${NC}"
echo -e "${GREEN}[✓] Configuration collected successfully! Proceeding with setup...${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

# 3. Install System Dependencies
echo -e "${BLUE}[*] Updating package repositories and installing core dependencies...${NC}"
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq curl git python3 python3-pip python3-venv python3-dev build-essential ufw >/dev/null 2>&1
  
  # Install Node.js 20 LTS if missing or outdated
  if ! command -v node >/dev/null 2>&1 || [ "$(node -v | cut -d'.' -f1 | tr -d 'v')" -lt 18 ]; then
    echo -e "${BLUE}[*] Installing Node.js 20 LTS runtime for Node.js bot instances...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
    apt-get install -y -qq nodejs >/dev/null 2>&1
  fi
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y -q curl git python3 python3-pip python3-devel gcc gcc-c++ make >/dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
  yum install -y -q curl git nodejs npm >/dev/null 2>&1
fi

echo -e "${GREEN}[✓] Node.js: $(node -v 2>&1 || echo 'Not installed')${NC}"
echo -e "${GREEN}[✓] npm: $(npm -v 2>&1 || echo 'Not installed')${NC}"

# 4. Download and Install Pre-Compiled Standalone Binary (Zero Source Code Exposed)
INSTALL_DIR="/opt/botcrafter"
BINARY_DEST="/usr/local/bin/botcrafter-server"
CONFIG_DIR="/etc/botcrafter"

echo -e "${BLUE}[*] Preparing BotCrafter binary installation (Source Code Protected)...${NC}"
mkdir -p "$CONFIG_DIR"
mkdir -p "$INSTALL_DIR"
mkdir -p "$DATA_DIR"
chmod -R 777 "$DATA_DIR"

# Download Release Binary URL (Defaults to GitHub release, overridable via BOTCRAFTER_BINARY_URL)
DEFAULT_BINARY_URL="https://github.com/RiadDeveloper/BotCrafter-Setup/releases/latest/download/botcrafter-server-linux-amd64"
BINARY_URL="${BOTCRAFTER_BINARY_URL:-$DEFAULT_BINARY_URL}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if local compiled binary is already present
if [ -f "$SCRIPT_DIR/backend/dist/botcrafter-server" ] || [ -f "$SCRIPT_DIR/botcrafter-server" ]; then
  echo -e "${GREEN}[*] Found local pre-compiled binary. Installing to ${BINARY_DEST}...${NC}"
  cp -f "$SCRIPT_DIR/backend/dist/botcrafter-server" "$BINARY_DEST" 2>/dev/null || cp -f "$SCRIPT_DIR/botcrafter-server" "$BINARY_DEST"
  chmod +x "$BINARY_DEST"
else
  echo -e "${BLUE}[*] Downloading compiled BotCrafter engine from release server...${NC}"
  echo -e "${CYAN}➜ URL: ${BINARY_URL}${NC}"
  
  if curl -fsSL -o "$BINARY_DEST" "$BINARY_URL"; then
    chmod +x "$BINARY_DEST"
    echo -e "${GREEN}[✓] Compiled binary downloaded and installed to ${BINARY_DEST}${NC}"
  else
    echo -e "${YELLOW}[!] Warning: Release binary could not be fetched from default URL.${NC}"
    echo -e "${YELLOW}[*] Falling back to automated local compiler...${NC}"
    
    # If binary release is not uploaded yet, compile locally on this VPS once into binary
    if [ ! -d "$INSTALL_DIR/.git" ] && [ ! -d "$SCRIPT_DIR/backend" ]; then
      git clone --depth 1 https://github.com/RiadDeveloper/BotCrafter.git "$INSTALL_DIR" --quiet
      SCRIPT_DIR="$INSTALL_DIR"
    fi
    
    apt-get install -y -qq python3 python3-pip python3-venv build-essential >/dev/null 2>&1 || true
    python3 -m venv "$INSTALL_DIR/.venv"
    "$INSTALL_DIR/.venv/bin/pip" install --upgrade pip -q
    "$INSTALL_DIR/.venv/bin/pip" install -r "$SCRIPT_DIR/backend/requirements.txt" -q
    "$INSTALL_DIR/.venv/bin/pip" install pyinstaller -q
    
    echo -e "${BLUE}[*] Compiling backend into protected binary...${NC}"
    cd "$SCRIPT_DIR/backend"
    "$INSTALL_DIR/.venv/bin/pyinstaller" --clean --noconfirm botcrafter.spec >/dev/null 2>&1
    cp -f "$SCRIPT_DIR/backend/dist/botcrafter-server" "$BINARY_DEST"
    chmod +x "$BINARY_DEST"
    
    # Remove source code after compiling to protect IP
    echo -e "${BLUE}[*] Purging source code files to protect intellectual property...${NC}"
    rm -rf "$SCRIPT_DIR/backend/app" "$SCRIPT_DIR/backend/dist" "$SCRIPT_DIR/backend/build" "$INSTALL_DIR/.git" 2>/dev/null || true
    echo -e "${GREEN}[✓] Binary successfully compiled and source files removed!${NC}"
  fi
fi

# 5. Generate Secure Environment Configuration (No Source Code)
echo -e "${BLUE}[*] Writing configuration to ${CONFIG_DIR}/botcrafter.env...${NC}"
cat <<EOF > "$CONFIG_DIR/botcrafter.env"
PROJECT_NAME="BotCrafter Engine"
ENVIRONMENT="production"
HOST="0.0.0.0"
PORT=${PORT}
SERVER_HOST_IP="${SERVER_HOST}"
SERVER_DOMAIN="${SERVER_HOST}"
DATA_DIR="${DATA_DIR}"
SUPABASE_URL="${SUPABASE_URL}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"
SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"
ADMIN_EMAIL="${ADMIN_EMAIL}"
ADMIN_PASSWORD="${ADMIN_PASSWORD}"
CORS_ORIGINS="*"
EOF

chmod 600 "$CONFIG_DIR/botcrafter.env"
echo -e "${GREEN}[✓] Configuration file created: ${CONFIG_DIR}/botcrafter.env${NC}"

# 6. Configure Systemd 24/7 Auto-Start Service for Compiled Binary
echo -e "${BLUE}[*] Configuring systemd daemon for compiled binary...${NC}"
SYSTEMD_FILE="/etc/systemd/system/botcrafter.service"

cat <<EOF > "$SYSTEMD_FILE"
[Unit]
Description=BotCrafter High-Performance Bot Engine (Compiled Binary)
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
EnvironmentFile=${CONFIG_DIR}/botcrafter.env
ExecStart=${BINARY_DEST}
Restart=always
RestartSec=5s
KillSignal=SIGTERM
TimeoutStopSec=30
StandardOutput=journal
StandardError=journal
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Reload and Enable systemd service
systemctl daemon-reload
systemctl enable botcrafter.service
systemctl restart botcrafter.service

# 9. Firewall Configuration (Open Port)
if command -v ufw >/dev/null 2>&1; then
  ufw allow "${PORT}/tcp" >/dev/null 2>&1 || true
fi

# 10. Install Global CLI Control Command: 'botcrafter'
CLI_CMD="/usr/local/bin/botcrafter"
cat <<'EOF' > "$CLI_CMD"
#!/usr/bin/env bash
CONFIG_FILE="/etc/botcrafter/botcrafter.env"
BINARY_DEST="/usr/local/bin/botcrafter-server"
SYSTEMD_FILE="/etc/systemd/system/botcrafter.service"

case "$1" in
  start)
    echo "[*] Starting BotCrafter Engine..."
    systemctl start botcrafter
    systemctl status botcrafter --no-pager
    ;;
  stop)
    echo "[*] Stopping BotCrafter Engine..."
    systemctl stop botcrafter
    ;;
  restart)
    echo "[*] Restarting BotCrafter Engine..."
    systemctl restart botcrafter
    systemctl status botcrafter --no-pager
    ;;
  status)
    systemctl status botcrafter --no-pager
    ;;
  logs)
    journalctl -u botcrafter -f -n 50
    ;;
  update)
    echo "=============================================================================="
    echo "[*] Updating BotCrafter Engine to Latest Release (Zero Data Loss)..."
    echo "=============================================================================="
    UPDATE_URL="https://github.com/RiadDeveloper/BotCrafter-Setup/releases/latest/download/botcrafter-server-linux-amd64"
    TMP_DEST="/tmp/botcrafter-server-new"
    echo "[*] Fetching latest binary release..."
    if curl -fsSL -o "$TMP_DEST" "$UPDATE_URL"; then
      chmod +x "$TMP_DEST"
      systemctl stop botcrafter 2>/dev/null || true
      mv -f "$TMP_DEST" "$BINARY_DEST"
      systemctl start botcrafter
      echo ""
      echo "[✓] BotCrafter Engine successfully updated to latest version!"
      echo "[✓] ZERO DATA LOSS: All bot instances, SQLite database, and configs preserved."
      echo "[*] Background 24/7 service restarted."
    else
      echo "[✗] Failed to download binary update from ${UPDATE_URL}."
      rm -f "$TMP_DEST" 2>/dev/null || true
    fi
    ;;
  set-ip)
    NEW_IP="$2"
    if [ -z "$NEW_IP" ]; then
      read -p "Enter new Server Public IP or Domain: " NEW_IP
    fi
    if [ -n "$NEW_IP" ] && [ -f "$CONFIG_FILE" ]; then
      sed -i "s|^SERVER_HOST_IP=.*|SERVER_HOST_IP=\"${NEW_IP}\"|g" "$CONFIG_FILE"
      sed -i "s|^SERVER_DOMAIN=.*|SERVER_DOMAIN=\"${NEW_IP}\"|g" "$CONFIG_FILE"
      systemctl restart botcrafter
      source "$CONFIG_FILE"
      echo ""
      echo "[✓] Server IP / Domain successfully updated to: ${NEW_IP}"
      echo "  🌐 Live Server URL: http://${NEW_IP}:${PORT}"
      echo "  📚 API Docs:        http://${NEW_IP}:${PORT}/docs"
    else
      echo "[✗] Invalid IP/domain or configuration file missing."
    fi
    ;;
  uninstall)
    echo "=============================================================================="
    echo "[!] WARNING: You are about to UNINSTALL BotCrafter from this system!"
    echo "=============================================================================="
    read -p "Are you sure you want to completely uninstall BotCrafter? [y/N]: " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
      echo "[*] Stopping BotCrafter service..."
      systemctl stop botcrafter 2>/dev/null || true
      systemctl disable botcrafter 2>/dev/null || true
      rm -f "$SYSTEMD_FILE"
      systemctl daemon-reload

      if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        if command -v ufw >/dev/null 2>&1 && [ -n "$PORT" ]; then
          echo "[*] Removing firewall rule for port ${PORT}..."
          ufw delete allow "${PORT}/tcp" >/dev/null 2>&1 || true
        fi
      fi

      rm -f "$BINARY_DEST"

      read -p "Do you also want to permanently delete all bot instance data in ${DATA_DIR:-/var/lib/botcrafter}? [y/N]: " DEL_DATA
      if [[ "$DEL_DATA" =~ ^[Yy]$ ]]; then
        rm -rf /var/lib/botcrafter
        rm -rf /etc/botcrafter
        echo "[✓] All bot instances and configurations completely removed."
      else
        rm -f "$CONFIG_FILE"
        echo "[!] Binaries & service removed. Bot data preserved in /var/lib/botcrafter."
      fi

      rm -f "$CLI_CMD"
      echo ""
      echo "[✓] BotCrafter has been completely and permanently uninstalled!"
    else
      echo "[*] Uninstallation cancelled."
    fi
    ;;
  info)
    echo "=========================================="
    echo "BotCrafter Service Information"
    echo "=========================================="
    if [ -f "$CONFIG_FILE" ]; then
      source "$CONFIG_FILE"
      echo "Status:        $(systemctl is-active botcrafter)"
      echo "Server URL:    http://${SERVER_HOST_IP}:${PORT}"
      echo "API Docs:      http://${SERVER_HOST_IP}:${PORT}/docs"
      echo "Storage Path:  ${DATA_DIR}"
      echo "Admin Email:   ${ADMIN_EMAIL}"
    fi
    echo "=========================================="
    ;;
  *)
    echo "BotCrafter CLI Manager"
    echo "Usage: botcrafter {status|logs|restart|stop|start|info|update|set-ip|uninstall}"
    exit 1
    ;;
esac
EOF

chmod +x "$CLI_CMD"

# Verify Service Health
sleep 3
SERVICE_STATUS=$(systemctl is-active botcrafter || echo "unknown")

# Final Presentation
echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${BOLD}${GREEN}   🎉 CONGRATULATIONS! BOTCRAFTER IS INSTALLED & RUNNING 24/7! 🎉${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "  🌐 ${BOLD}Live Backend Server URL:${NC} ${CYAN}http://${SERVER_HOST}:${PORT}${NC}"
echo -e "  📚 ${BOLD}Interactive API Docs:${NC}    ${CYAN}http://${SERVER_HOST}:${PORT}/docs${NC}"
echo -e "  👤 ${BOLD}Administrator Email:${NC}     ${YELLOW}${ADMIN_EMAIL}${NC}"
echo -e "  💾 ${BOLD}Instance Storage Path:${NC}   ${YELLOW}${DATA_DIR}${NC}"
echo -e "  🔄 ${BOLD}Auto-Recovery on Boot:${NC}   ${GREEN}ENABLED (systemd service)${NC}"
echo -e "  ⚡ ${BOLD}Service Health Status:${NC}   ${GREEN}${SERVICE_STATUS}${NC}"
echo ""
echo -e "${BOLD}${MAGENTA}━━━━━━━━━━━━━━━━━━━ [ Management CLI Commands ] ━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ➜ Check service status:   ${CYAN}botcrafter status${NC}"
echo -e "  ➜ View live server logs:  ${CYAN}botcrafter logs${NC}"
echo -e "  ➜ Restart backend engine: ${CYAN}botcrafter restart${NC}"
echo -e "  ➜ Stop backend engine:    ${CYAN}botcrafter stop${NC}"
echo -e "  ➜ Start backend engine:   ${CYAN}botcrafter start${NC}"
echo -e "  ➜ View server info:       ${CYAN}botcrafter info${NC}"
echo -e "  ➜ Update engine (No loss):${CYAN}botcrafter update${NC}"
echo -e "  ➜ Change server IP:       ${CYAN}botcrafter set-ip <new_ip>${NC}"
echo -e "  ➜ Uninstall BotCrafter:   ${CYAN}botcrafter uninstall${NC}"
echo ""
echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BOLD}${YELLOW}📌 Note:${NC} You can connect your Frontend (Vercel or Local) by setting:"
echo -e "   NEXT_PUBLIC_API_URL=http://${SERVER_HOST}:${PORT}"
echo -e "   NEXT_PUBLIC_WS_URL=ws://${SERVER_HOST}:${PORT}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""
