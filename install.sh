#!/bin/bash
# ==========================================================
# IMAGITECH ENTERPRISE - Master Deployment Pipeline
# ==========================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

REPO_URL="https://raw.githubusercontent.com/dexteree11/vpn-autoscript/main"

clear
echo -e "${CYAN}======================================================${NC}"
echo -e "${GREEN}${BOLD}    IMAGITECH ENTERPRISE INFRASTRUCTURE DEPLOYMENT    ${NC}"
echo -e "${CYAN}======================================================${NC}"

if [ "${EUID}" -ne 0 ]; then
    echo -e "${RED}[FATAL] This pipeline requires root privileges. (Type: sudo su -)${NC}"
    exit 1
fi

# --- 1. OS Preparation & Dependencies ---
echo -e "\n${CYAN}[*] Phase 1: Provisioning OS Dependencies...${NC}"
systemctl stop apt-daily.timer 2>/dev/null
rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock*

DEBIAN_FRONTEND=noninteractive apt-get update -y --fix-missing > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --fix-broken \
    curl wget git sqlite3 python3 cron iptables lsof \
    software-properties-common ca-certificates openssl \
    dropbear stunnel4 dante-server > /dev/null 2>&1

# --- 2. Architecture Scaffolding ---
echo -e "${CYAN}[*] Phase 2: Building Enterprise Filesystem...${NC}"
mkdir -p /opt/imagitech/{bin,core/keys,lib,logs,menus}
chmod 700 /opt/imagitech/logs

# --- 3. Fetching Core Libraries & Backend ---
echo -e "${CYAN}[*] Phase 3: Fetching MVC Components...${NC}"

# Libs
curl -sS -o /opt/imagitech/lib/logger.sh "$REPO_URL/lib/logger.sh"
curl -sS -o /opt/imagitech/lib/ui.sh "$REPO_URL/lib/ui.sh"

# Core & DB
curl -sS -o /opt/imagitech/core/init_db.sh "$REPO_URL/core/init_db.sh"
chmod +x /opt/imagitech/core/init_db.sh
bash /opt/imagitech/core/init_db.sh > /dev/null 2>&1

# Python Monitor
curl -sS -o /opt/imagitech/bin/monitor.py "$REPO_URL/bin/monitor.py"
chmod +x /opt/imagitech/bin/monitor.py

# CLI Router
curl -sS -o /usr/bin/imagitech "$REPO_URL/bin/imagitech"
chmod +x /usr/bin/imagitech

# Menus
curl -sS -o /usr/bin/menu "$REPO_URL/bin/menu"
chmod +x /usr/bin/menu

MENUS=("main.sh" "01_ssh.sh" "02_domain.sh" "03_services.sh")
for m in "${MENUS[@]}"; do
    curl -sS -o "/opt/imagitech/menus/$m" "$REPO_URL/menus/$m"
done

# --- 4. Daemonizing the Python Enforcer ---
echo -e "${CYAN}[*] Phase 4: Initializing Stateful Security Daemon...${NC}"
cat <<EOF > /etc/systemd/system/imagitech-monitor.service
[Unit]
Description=Imagitech Multi-Login Enforcer Daemon
After=network.target sqlite3.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /opt/imagitech/bin/monitor.py
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable imagitech-monitor > /dev/null 2>&1
systemctl restart imagitech-monitor

# --- 5. Finalizing ---
echo -e "\n${CYAN}======================================================${NC}"
echo -e "${GREEN}${BOLD}    DEPLOYMENT SUCCESSFUL                             ${NC}"
echo -e "${CYAN}======================================================${NC}"
echo -e "  - MVC Architecture   : ${GREEN}ONLINE${NC}"
echo -e "  - SQLite Database    : ${GREEN}INITIALIZED${NC}"
echo -e "  - Multi-Login Daemon : ${GREEN}ACTIVE${NC}"
echo -e "  - Global CLI         : ${GREEN}/usr/bin/imagitech${NC}"
echo -e "\nType ${GREEN}menu${NC} to access the enterprise dashboard."
