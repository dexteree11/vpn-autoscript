#!/bin/bash
# ==========================================================
# IMAGITECH ENTERPRISE - Core Protocol Provisioning
# ==========================================================

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[0;33m'
NC='\033[0m'

echo -e "${CYAN}[*] Phase 5: Initializing Core Protocol Engine...${NC}"

# --- 1. Domain Collection ---
while true; do
    read -p "Primary VPN Domain (e.g., vpn.imagitech.online): " DOMAIN
    if [[ -n "$DOMAIN" ]]; then break; fi
done

while true; do
    read -p "Nameserver Domain (e.g., ns.imagitech.online): " NS_DOMAIN
    if [[ -n "$NS_DOMAIN" ]]; then break; fi
done

echo "$DOMAIN" > /opt/imagitech/core/domain.txt
echo "$NS_DOMAIN" > /opt/imagitech/core/ns_domain.txt

# --- 2. Let's Encrypt & TLS Fallback ---
echo -e "${CYAN}  -> Generating Cryptographic Identity...${NC}"
curl -sL https://get.acme.sh | sh -s email=admin@${DOMAIN} > /dev/null 2>&1
/root/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --keylength ec-256 --force > /dev/null 2>&1
/root/.acme.sh/acme.sh --installcert -d "$DOMAIN" --ecc \
    --fullchain-file /opt/imagitech/core/keys/fullchain.cer \
    --key-file /opt/imagitech/core/keys/private.key > /dev/null 2>&1

if [ ! -s "/opt/imagitech/core/keys/fullchain.cer" ]; then
    echo -e "${RED}  [!] Let's Encrypt failed. Generating Fallback Cert...${NC}"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /opt/imagitech/core/keys/private.key \
        -out /opt/imagitech/core/keys/fullchain.cer \
        -subj "/C=US/ST=NY/L=NY/O=Imagitech/CN=$DOMAIN" > /dev/null 2>&1
fi

cat /opt/imagitech/core/keys/fullchain.cer /opt/imagitech/core/keys/private.key > /opt/imagitech/core/keys/stunnel.pem
chmod 600 /opt/imagitech/core/keys/stunnel.pem

# --- 3. Dropbear & Dante (Core SSH/SOCKS5) ---
echo -e "${CYAN}  -> Configuring Dropbear & SOCKS5...${NC}"
cat <<EOF > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143 -w -g"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
EOF
echo "<font color='green'><b>IMAGITECH ENTERPRISE</b></font>" > /etc/issue.net
systemctl restart dropbear

IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
cat <<EOF > /etc/danted.conf
logoutput: syslog
user.privileged: root
user.unprivileged: nobody
internal: 0.0.0.0 port = 1080
external: ${IFACE}
socksmethod: username
clientmethod: none
client pass { from: 0.0.0.0/0 to: 0.0.0.0/0 }
socks pass { from: 0.0.0.0/0 to: 0.0.0.0/0 }
EOF
systemctl restart danted

# --- 4. Python WS-Proxy (Port 80/8880 Multiplexer) ---
echo -e "${CYAN}  -> Deploying WebSocket Multiplexer...${NC}"
cat <<'EOF' > /opt/imagitech/bin/ws-proxy.py
import socket, threading, select
def handle_client(client_socket):
    try:
        request = client_socket.recv(8192)
        if not request: return
        req_str = request.decode('utf-8', errors='ignore')
        if "HTTP/" in req_str or "Upgrade:" in req_str:
            client_socket.sendall(b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n")
        backend = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        backend.connect(('127.0.0.1', 109))
        if "HTTP/" not in req_str: backend.sendall(request)
        sockets = [client_socket, backend]
        while True:
            r, _, e = select.select(sockets, [], sockets)
            if e: break
            for sock in r:
                data = sock.recv(8192)
                if not data: break
                if sock is client_socket: backend.sendall(data)
                else: client_socket.sendall(data)
    except: pass
    finally: client_socket.close()

def start_server(port):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', port))
    server.listen(100)
    while True:
        c, _ = server.accept()
        threading.Thread(target=handle_client, args=(c,), daemon=True).start()

if __name__ == '__main__':
    threading.Thread(target=start_server, args=(80,), daemon=True).start()
    threading.Thread(target=start_server, args=(8880,), daemon=True).start()
    import time; time.sleep(9999999)
EOF

chmod +x /opt/imagitech/bin/ws-proxy.py
cat <<EOF > /etc/systemd/system/ws-proxy.service
[Unit]
Description=Imagitech WS Multiplexer
[Service]
ExecStart=/usr/bin/python3 /opt/imagitech/bin/ws-proxy.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable --now ws-proxy

# --- 5. Stunnel4 (Port 443 Decryption) ---
echo -e "${CYAN}  -> Configuring Stunnel SSL Decryption Layer...${NC}"
cat <<EOF > /etc/stunnel/stunnel.conf
pid = /var/run/stunnel.pid
cert = /opt/imagitech/core/keys/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[ssh-ws-ssl]
accept = 443
connect = 127.0.0.1:80
EOF
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
systemctl restart stunnel4

# --- 6. Compile BadVPN & DNSTT ---
echo -e "${CYAN}  -> Compiling BadVPN & DNSTT (This takes a moment)...${NC}"
cd /tmp
git clone https://github.com/ambrop72/badvpn.git > /dev/null 2>&1
cd badvpn
mkdir -p build && cd build
cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 > /dev/null 2>&1 && make install > /dev/null 2>&1
cat <<EOF > /etc/systemd/system/badvpn-7100.service
[Unit]
Description=BadVPN UDPGW
[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 500
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable --now badvpn-7100

cd /tmp
curl -sL -o go.tar.gz https://go.dev/dl/go1.21.6.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go.tar.gz
export PATH=$PATH:/usr/local/go/bin
git clone https://www.bamsoftware.com/git/dnstt.git > /dev/null 2>&1
cd dnstt/dnstt-server && go build > /dev/null 2>&1
mv dnstt-server /opt/imagitech/bin/

# Generate Static Keys via our CLI Router
/usr/bin/imagitech dnstt keygen --force > /dev/null 2>&1

cat <<EOF > /etc/systemd/system/dnstt.service
[Unit]
Description=DNSTT Server
[Service]
ExecStart=/opt/imagitech/bin/dnstt-server -udp :5300 -privkey-file /opt/imagitech/core/keys/dnstt.key ${NS_DOMAIN} 127.0.0.1:109
Restart=always
[Install]
WantedBy=multi-user.target
EOF
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
netfilter-persistent save > /dev/null 2>&1
systemctl daemon-reload && systemctl enable --now dnstt

# Save iptables routing across reboots
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent > /dev/null 2>&1
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
netfilter-persistent save > /dev/null 2>&1

# Ensure ALL core services start on server reboot
systemctl daemon-reload
systemctl enable --now dnstt dropbear stunnel4 danted ws-proxy badvpn-7100

echo -e "${GREEN}[+] Protocol Engine Provisioned Successfully!${NC}"
