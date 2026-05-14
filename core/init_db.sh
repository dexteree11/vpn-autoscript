#!/bin/bash
# ==========================================================
# IMAGITECH CORE - Database Schema Initialization
# ==========================================================

DB_PATH="/opt/imagitech/core/imagitech.db"
mkdir -p /opt/imagitech/core

echo "Initializing Relational Schema..."

sqlite3 "$DB_PATH" <<EOF
PRAGMA foreign_keys = ON;

-- The Core Identity Object
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    expiry_date DATETIME NOT NULL,
    max_logins INTEGER DEFAULT 1,
    status TEXT DEFAULT 'ACTIVE',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- The Service Abstraction Object
CREATE TABLE IF NOT EXISTS services (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    backend_port INTEGER NOT NULL,
    protocol TEXT NOT NULL
);

-- The Transport/Permission Matrix
CREATE TABLE IF NOT EXISTS user_access (
    user_id INTEGER,
    service_id INTEGER,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY(service_id) REFERENCES services(id) ON DELETE CASCADE
);

-- Seed the Default ISP Bypass Services
INSERT OR IGNORE INTO services (name, backend_port, protocol) VALUES ('openssh', 22, 'tcp');
INSERT OR IGNORE INTO services (name, backend_port, protocol) VALUES ('dropbear', 109, 'tcp');
INSERT OR IGNORE INTO services (name, backend_port, protocol) VALUES ('socks5', 1080, 'tcp');
INSERT OR IGNORE INTO services (name, backend_port, protocol) VALUES ('dnstt', 5300, 'udp');
EOF

chmod 600 "$DB_PATH"
echo "Schema Locked."
