#!/bin/bash
# ==========================================================
# IMAGITECH CORE - 01 SSH Panel (View/Controller)
# ==========================================================

source /opt/imagitech/lib/ui.sh
DB_PATH="/opt/imagitech/core/imagitech.db"

# --- View/Action Handlers ---

action_create_user() {
    clear
    draw_top
    print_center "PROVISION NEW SSH ACCOUNT" "${BOLD}${CYAN}"
    draw_mid
    prompt_input "Username" username
    prompt_input "Password" password
    prompt_input "Duration (Days)" days
    prompt_input "Max Active Logins (Default: 1)" logins
    
    # Set default if empty
    logins=${logins:-1}

    echo ""
    draw_line
    # ⚡ THE THIN WRAPPER: Passing execution to the global router
    imagitech user add "$username" "$password" "$days" "$logins"
    pause_menu
}

action_delete_user() {
    clear
    draw_top
    print_center "TERMINATE SSH ACCOUNT" "${BOLD}${RED}"
    draw_mid
    prompt_input "Username to Delete" username

    echo ""
    draw_line
    imagitech user del "$username"
    pause_menu
}

action_list_members() {
    clear
    draw_top
    print_center "REGISTERED SYSTEM USERS" "${BOLD}${CYAN}"
    draw_mid
    
    # Formatted Header
    printf "  ${ORANGE}%-15s %-12s %-10s %-10s${NC}\n" "USERNAME" "EXPIRY" "LIMIT" "STATUS"
    draw_line
    
    # Instant SQLite Read & Format
    sqlite3 "$DB_PATH" "SELECT username, date(expiry_date), max_logins, status FROM users;" | \
    awk -F'|' -v red="$RED" -v green="$GREEN" -v nc="$NC" '{
        status_color = ($4 == "ACTIVE") ? green : red;
        printf "  %-15s %-12s %-10s %s%s%s\n", $1, $2, $3, status_color, $4, nc
    }'
    
    draw_bot
    pause_menu
}

action_user_details() {
    clear
    draw_top
    print_center "QUERY USER RECORD" "${BOLD}${CYAN}"
    draw_mid
    prompt_input "Enter Username" username
    echo ""
    
    # Fetch exact record from database
    RECORD=$(sqlite3 "$DB_PATH" "SELECT password, expiry_date, max_logins, status, created_at FROM users WHERE username='$username';")
    
    if [[ -z "$RECORD" ]]; then
        echo -e "  ${RED}Error: User '$username' not found in database.${NC}"
    else
        draw_line
        echo "$RECORD" | awk -F'|' -v u="$username" '{
            print "  Username   : " u
            print "  Password   : " $1
            print "  Expiry Date: " $2
            print "  Max Logins : " $3
            print "  Status     : " $4
            print "  Created On : " $5
        }'
    fi
    pause_menu
}

# --- The Sub-Menu HUD ---

show_ssh_menu() {
    clear
    draw_top
    print_center "SSH IDENTITY MANAGEMENT" "${BOLD}${ACCENT_COLOR}"
    draw_mid
    
    echo -e "  ${CYAN}[01]${NC} Create SSH Account     ${CYAN}[07]${NC} Multi-login Monitor"
    echo -e "  ${CYAN}[02]${NC} Create Trial SSH       ${CYAN}[08]${NC} List Members"
    echo -e "  ${CYAN}[03]${NC} Renew SSH Account      ${CYAN}[09]${NC} Bandwidth Usage"
    echo -e "  ${CYAN}[04]${NC} Delete SSH Account     ${CYAN}[10]${NC} User Details"
    echo -e "  ${CYAN}[05]${NC} Lock / Unlock User     ${CYAN}[11]${NC} Kill Active Session"
    echo -e "  ${CYAN}[06]${NC} Check Online Users"
    echo -e "  "
    echo -e "  ${RED}[00] Return to Main Menu${NC}"
    
    draw_bot
    echo ""
    prompt_input "Select Module" opt

    case $opt in
        1) action_create_user ;;
        # 2) action_create_trial ;; # Placeholder for future logic
        # 3) action_renew_user ;;   # Placeholder for future logic
        4) action_delete_user ;;
        8) action_list_members ;;
        10) action_user_details ;;
        0) exit 0 ;; # Exiting the sub-script returns control to the Main HUB
        *) show_ssh_menu ;;
    esac
}

# Execution Loop
while true; do
    show_ssh_menu
done
