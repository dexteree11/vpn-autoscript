#!/bin/bash
# ==========================================================
# IMAGITECH CORE - 02 Domain & SSL Panel (View/Controller)
# ==========================================================

source /opt/imagitech/lib/ui.sh

# --- View/Action Handlers ---

action_change_host() {
    clear
    draw_top
    print_center "UPDATE PRIMARY HOST DOMAIN" "${BOLD}${CYAN}"
    draw_mid
    echo -e "  ${ORANGE}Current Domain:${NC} $(cat /opt/imagitech/core/domain.txt 2>/dev/null || echo 'None')"
    echo ""
    prompt_input "Enter New Domain" new_domain

    if [[ -n "$new_domain" ]]; then
        echo ""
        draw_line
        imagitech domain host "$new_domain"
    fi
    pause_menu
}

action_change_ns() {
    clear
    draw_top
    print_center "UPDATE NAMESERVER (DNSTT) DOMAIN" "${BOLD}${CYAN}"
    draw_mid
    echo -e "  ${ORANGE}Current NS:${NC} $(cat /opt/imagitech/core/ns_domain.txt 2>/dev/null || echo 'None')"
    echo ""
    prompt_input "Enter New NS Domain" new_ns

    if [[ -n "$new_ns" ]]; then
        echo ""
        draw_line
        imagitech domain ns "$new_ns"
    fi
    pause_menu
}

action_renew_ssl() {
    clear
    draw_top
    print_center "LET'S ENCRYPT CERTIFICATE RENEWAL" "${BOLD}${MAGENTA}"
    draw_mid
    echo -e "  ${ORANGE}Warning:${NC} This will temporarily stop port 80/443."
    prompt_input "Type 'Y' to confirm renewal" confirm
    
    if [[ "${confirm,,}" == "y" ]]; then
        echo ""
        draw_line
        imagitech cert renew
    fi
    pause_menu
}

action_view_cert() {
    clear
    draw_top
    print_center "CERTIFICATE STATUS" "${BOLD}${CYAN}"
    draw_mid
    
    # State reading is fine in the View layer
    CERT_FILE="/opt/imagitech/core/keys/fullchain.cer"
    if [ -f "$CERT_FILE" ]; then
        ISSUER=$(openssl x509 -issuer -noout -in "$CERT_FILE" | cut -d= -f3-)
        DATES=$(openssl x509 -dates -noout -in "$CERT_FILE")
        DOMAIN=$(openssl x509 -subject -noout -in "$CERT_FILE" | grep -o 'CN = .*' | cut -d' ' -f3)
        
        echo -e "  ${CYAN}Domain :${NC} $DOMAIN"
        echo -e "  ${CYAN}Issuer :${NC} $ISSUER"
        echo -e "  ${CYAN}Valid  :${NC} $(echo "$DATES" | grep notBefore | cut -d= -f2)"
        echo -e "  ${CYAN}Expiry :${NC} $(echo "$DATES" | grep notAfter | cut -d= -f2)"
    else
        echo -e "  ${RED}Error: No SSL certificate found at $CERT_FILE${NC}"
    fi
    
    draw_bot
    pause_menu
}

action_generate_key() {
    clear
    draw_top
    print_center "REGENERATE SLOWDNS KEYS" "${BOLD}${RED}"
    draw_mid
    echo -e "  ${RED}DANGER:${NC} Changing this key will disconnect ALL current"
    echo -e "  SlowDNS users until they update their payloads!"
    echo ""
    prompt_input "Type 'REGENERATE' to confirm" confirm
    
    if [[ "$confirm" == "REGENERATE" ]]; then
        echo ""
        draw_line
        imagitech dnstt keygen --force
    fi
    pause_menu
}

action_show_domains() {
    clear
    draw_top
    print_center "CURRENT ROUTING IDENTITIES" "${BOLD}${CYAN}"
    draw_mid
    
    HOST=$(cat /opt/imagitech/core/domain.txt 2>/dev/null || echo "Not Configured")
    NS=$(cat /opt/imagitech/core/ns_domain.txt 2>/dev/null || echo "Not Configured")
    PUBKEY=$(cat /opt/imagitech/core/keys/dnstt.pub 2>/dev/null || echo "Not Generated")
    
    echo -e "  ${CYAN}Primary Host :${NC} $HOST"
    echo -e "  ${CYAN}Nameserver   :${NC} $NS"
    echo -e "  ${CYAN}DNSTT PubKey :${NC} $PUBKEY"
    
    draw_bot
    pause_menu
}

# --- The Sub-Menu HUD ---

show_domain_menu() {
    clear
    draw_top
    print_center "DOMAIN & SSL MANAGEMENT" "${BOLD}${ACCENT_COLOR}"
    draw_mid
    
    echo -e "  ${CYAN}[01]${NC} Change Host Domain     ${CYAN}[04]${NC} View Certificate Status"
    echo -e "  ${CYAN}[02]${NC} Change NS Domain       ${CYAN}[05]${NC} Generate New SlowDNS Key"
    echo -e "  ${CYAN}[03]${NC} Renew SSL Certificate  ${CYAN}[06]${NC} Show Current Domains"
    echo -e "  "
    echo -e "  ${RED}[00] Return to Main Menu${NC}"
    
    draw_bot
    echo ""
    prompt_input "Select Module" opt

    case $opt in
        1) action_change_host ;;
        2) action_change_ns ;;
        3) action_renew_ssl ;;
        4) action_view_cert ;;
        5) action_generate_key ;;
        6) action_show_domains ;;
        0) exit 0 ;; 
        *) show_domain_menu ;;
    esac
}

# Execution Loop
while true; do
    show_domain_menu
done
