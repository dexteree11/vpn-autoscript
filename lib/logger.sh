#!/bin/bash
# ==========================================================
# IMAGITECH CORE - Event Logging Subsystem
# ==========================================================

LOG_DIR="/opt/imagitech/logs"
mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR"

log_event() {
    local category=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" >> "$LOG_DIR/${category}.log"
}

# Helper functions for the three main log streams
log_auth() { log_event "auth" "$1"; }
log_sys()  { log_event "system" "$1"; }
log_sec()  { log_event "security" "$1"; }
