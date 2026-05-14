#!/bin/bash
# ==========================================================
# IMAGITECH CORE - UI & Styling Library
# ==========================================================

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Box Drawing Characters (Isolated for easy theme changes)
BORDER_COLOR="${CYAN}"
TEXT_COLOR="${NC}"
ACCENT_COLOR="${GREEN}"

draw_top() { echo -e "${BORDER_COLOR}┌────────────────────────────────────────────────────────┐${NC}"; }
draw_mid() { echo -e "${BORDER_COLOR}├────────────────────────────────────────────────────────┤${NC}"; }
draw_bot() { echo -e "${BORDER_COLOR}└────────────────────────────────────────────────────────┘${NC}"; }
draw_line(){ echo -e "${BORDER_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# Dynamic Centering Function
print_center() {
    local text="$1"
    local color="$2"
    local total_width=54
    local text_width=${#text}
    local padding=$(( (total_width - text_width) / 2 ))
    
    printf "${BORDER_COLOR}│${NC} %${padding}s${color}${text}${NC}%$((total_width - text_width - padding))s ${BORDER_COLOR}│${NC}\n" "" ""
}

# Standardized Prompts
prompt_input() {
    local message="$1"
    local var_name="$2"
    read -p "$(echo -e " ${ORANGE}➤${NC} ${message}: ")" $var_name
}

pause_menu() {
    echo ""
    read -n 1 -s -r -p " Press any key to return..."
}
