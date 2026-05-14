#!/bin/bash
# ==========================================================
# IMAGITECH CORE - The Main HUB
# ==========================================================

# Source the UI Library
source /opt/imagitech/lib/ui.sh

# --- Dynamic Harvesters ---

get_public_ip() {
    PUBLIC_IP=$(curl -sS --max-time 3 ipv4.icanhazip.com || echo "UNKNOWN")
}

get_load_average() {
    LOAD_AVG=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    UPTIME=$(uptime -p | sed 's/up //')
}

get_active_connections() {
    # Lightweight socket count for SSH/Dropbear/SOCKS5. 
    # (The Python Daemon will handle exact per-user limits later)
    ACTIVE_CONNS=$(ss -tnp state established 2>/dev/null | grep -E 'dropbear|sshd|danted' | wc -l)
}

get_cert_expiry() {
    CERT_FILE="/opt/imagitech/core/keys/fullchain.cer"
    if [ -f "$CERT_FILE" ]; then
        EXP_DATE=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
        EXP_SEC=$(date -d "$EXP_DATE" +%s)
        NOW_SEC=$(date +%s)
        DAYS_LEFT=$(( (EXP_SEC - NOW_SEC) / 86400 ))
        
        if [ "$DAYS_LEFT" -le 7 ]; then
            CERT_STATUS="${RED}${DAYS_LEFT} Days (RENEW NOW)${NC}"
        else
            CERT_STATUS="${GREEN}${DAYS_LEFT} Days${NC}"
        fi
    else
        CERT_STATUS="${RED}No Certificate Found${NC}"
    fi
}

# --- The HUD Rendering ---

show_main_menu() {
    clear
    get_public_ip
    get_load_average
    get_active_connections
    get_cert_expiry

    draw_top
    print_center "IMAGITECH ENTERPRISE INFRASTRUCTURE" "${BOLD}${ACCENT_COLOR}"
    draw_mid
    
    echo -e "  ${ORANGE}✦ Public IP${NC}       : ${CYAN}${PUBLIC_IP}${NC}"
    echo -e "  ${ORANGE}✦ Server Load${NC}     : ${CYAN}${LOAD_AVG}${NC} (${UPTIME})"
    echo -e "  ${ORANGE}✦ Active Sockets${NC}  : ${GREEN}${ACTIVE_CONNS} Connections${NC}"
    echo -e "  ${ORANGE}✦ Cert Expiry${NC}     : ${CERT_STATUS}"
    
    draw_mid
    
    echo -e "  ${CYAN}[01]${NC} SSH PANEL           ${CYAN}[05]${NC} SETTINGS"
    echo -e "  ${CYAN}[02]${NC} DOMAIN & SSL        ${CYAN}[06]${NC} SYSTEM TOOLS"
    echo -e "  ${CYAN}[03]${NC} RUNNING SERVICES    ${CYAN}[07]${NC} BACKUP & RESTORE"
    echo -e "  ${CYAN}[04]${NC} MONITORING          ${CYAN}[08]${NC} UPDATE SCRIPT"
    echo -e "  "
    echo -e "  ${RED}[00] EXIT PANEL${NC}"
    
    draw_bot
    echo ""
    prompt_input "Select Module" opt

    case $opt in
        1) bash /opt/imagitech/menus/01_ssh.sh ;;
        2) bash /opt/imagitech/menus/02_domain.sh ;;
        3) bash /opt/imagitech/menus/03_services.sh ;;
        4) bash /opt/imagitech/menus/04_monitor.sh ;;
        5) bash /opt/imagitech/menus/05_settings.sh ;;
        6) bash /opt/imagitech/menus/06_tools.sh ;;
        7) bash /opt/imagitech/menus/07_backup.sh ;;
        8) bash /opt/imagitech/menus/08_update.sh ;;
        0) clear; exit 0 ;;
        *) show_main_menu ;;
    esac
}

# Execution Loop
while true; do
    show_main_menu
done
