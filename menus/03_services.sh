#!/bin/bash
# ==========================================================
# IMAGITECH CORE - 03 Running Services (View/Controller)
# ==========================================================

source /opt/imagitech/lib/ui.sh

# --- View/Action Handlers ---

action_restart() {
    local service_name=$1
    local display_name=$2
    
    clear
    draw_top
    print_center "RESTARTING ${display_name^^}" "${BOLD}${CYAN}"
    draw_mid
    echo -e "  ${ORANGE}[*]${NC} Sending restart signal to ${service_name}..."
    echo ""
    draw_line
    
    # Delegate to global router
    imagitech service restart "$service_name"
    pause_menu
}

action_restart_all() {
    clear
    draw_top
    print_center "RESTARTING ALL SERVICES" "${BOLD}${RED}"
    draw_mid
    
    services=("ssh" "dropbear" "ws-proxy" "stunnel4" "dnstt" "danted")
    
    for svc in "${services[@]}"; do
        echo -ne "  ${CYAN}✦${NC} Restarting ${svc}... "
        imagitech service restart "$svc" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[OK]${NC}"
        else
            echo -e "${RED}[FAIL]${NC}"
        fi
    done
    
    draw_bot
    pause_menu
}

action_view_failed() {
    clear
    draw_top
    print_center "FAILED SYSTEM SERVICES" "${BOLD}${RED}"
    draw_mid
    
    # Call router for system state
    imagitech service failed
    
    draw_bot
    pause_menu
}

action_view_ports() {
    clear
    draw_top
    print_center "ACTIVE LISTENING PORTS" "${BOLD}${CYAN}"
    draw_mid
    
    # Call router for network state
    imagitech service ports
    
    draw_bot
    pause_menu
}

# --- The Sub-Menu HUD ---

show_services_menu() {
    clear
    draw_top
    print_center "SERVICE ORCHESTRATION" "${BOLD}${ACCENT_COLOR}"
    draw_mid
    
    echo -e "  ${CYAN}[01]${NC} Restart SSH            ${CYAN}[06]${NC} Restart SOCKS5"
    echo -e "  ${CYAN}[02]${NC} Restart Dropbear       ${CYAN}[07]${NC} Restart All Services"
    echo -e "  ${CYAN}[03]${NC} Restart WebSocket      ${CYAN}[08]${NC} View Failed Services"
    echo -e "  ${CYAN}[04]${NC} Restart Stunnel        ${CYAN}[09]${NC} View Listening Ports"
    echo -e "  ${CYAN}[05]${NC} Restart DNSTT"
    echo -e "  "
    echo -e "  ${RED}[00] Return to Main Menu${NC}"
    
    draw_bot
    echo ""
    prompt_input "Select Module" opt

    case $opt in
        1) action_restart "ssh" "OpenSSH" ;;
        2) action_restart "dropbear" "Dropbear" ;;
        3) action_restart "ws-proxy" "WebSocket Proxy" ;;
        4) action_restart "stunnel4" "Stunnel SSL" ;;
        5) action_restart "dnstt" "SlowDNS" ;;
        6) action_restart "danted" "Dante SOCKS5" ;;
        7) action_restart_all ;;
        8) action_view_failed ;;
        9) action_view_ports ;;
        0) exit 0 ;;
        *) show_services_menu ;;
    esac
}

# Execution Loop
while true; do
    show_services_menu
done
