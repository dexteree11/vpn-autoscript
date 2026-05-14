#!/usr/bin/env python3
# ==========================================================
# IMAGITECH CORE - Stateful Multi-Login Monitor Daemon
# ==========================================================

import sqlite3
import subprocess
import time
from datetime import datetime

DB_PATH = "/opt/imagitech/core/imagitech.db"
LOG_PATH = "/opt/imagitech/logs/security.log"
POLL_INTERVAL = 10 # Seconds between checks

def log_security(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_PATH, "a") as log_file:
        log_file.write(f"[{timestamp}] {message}\n")

def enforce_limits():
    try:
        # 1. Fetch Single Source of Truth from SQLite
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT username, max_logins FROM users WHERE status='ACTIVE'")
        user_limits = {row[0]: row[1] for row in cursor.fetchall()}
        conn.close()

        # 2. Snapshot the Kernel Process Tree
        # 'ruser' gets the real executing user, which perfectly tracks our PAM accounts
        ps_cmd = subprocess.Popen(['ps', '-eo', 'ruser,pid,comm'], stdout=subprocess.PIPE, text=True)
        output, _ = ps_cmd.communicate()

        active_sessions = {}
        
        for line in output.splitlines()[1:]: # Skip the header
            parts = line.strip().split()
            if len(parts) >= 3:
                user, pid, comm = parts[0], parts[1], parts[2]
                
                # Filter strictly for our VPN transport binaries
                if comm in ['dropbear', 'sshd', 'danted']:
                    if user in user_limits:
                        if user not in active_sessions:
                            active_sessions[user] = []
                        active_sessions[user].append(pid)

        # 3. Enforce the Policy Matrix
        for user, pids in active_sessions.items():
            max_logins = user_limits[user]
            current_logins = len(pids)

            if current_logins > max_logins:
                log_security(f"VIOLATION: User '{user}' exceeded limit ({current_logins}/{max_logins}). Terminating active sockets.")
                
                # Strict Penalty: Forcibly drop all transport processes for the offending user
                subprocess.run(['pkill', '-u', user, '-f', 'dropbear|sshd|danted'])
                
    except Exception as e:
        log_security(f"DAEMON CRASH RECOVERED: {str(e)}")

if __name__ == "__main__":
    log_security("DAEMON STARTED: Imagitech Multi-Login Monitor Initialized.")
    while True:
        enforce_limits()
        time.sleep(POLL_INTERVAL)
