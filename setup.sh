#!/bin/bash
# Skript pro nastavení Raspberry Pi jako DHCP routeru s NAT a reverzní proxy (nginx)
# pro vzdálený přístup k 3D tiskárnám přes PrusaLink.

set -e  # Ukončí skript při jakékoliv chybě

echo "Aktualizace systému..."
apt update
apt upgrade -y

# Instalace potřebných balíčků
echo "Instaluji potřebné balíčky: network-manager, nmap, isc-dhcp-server, iptables, iptables-persistent, nginx..."
apt install -y network-manager nmap isc-dhcp-server iptables iptables-persistent nginx

# Deaktivace starých síťových manažerů (přechod plně na NetworkManager)
echo "Deaktivuji dhcpcd a systemd-networkd (pokud existují)..."
systemctl stop dhcpcd systemd-networkd || true
systemctl disable dhcpcd systemd-networkd || true

# Odstranění starých připojení na eth1 a vytvoření nového pomocí nmcli
echo "Nastavuji statickou IP adresu na eth1 pomocí NetworkManageru..."
nmcli connection delete eth1 || true
nmcli connection delete ethernet-eth1 || true
nmcli connection delete "PRINTER-NET" || true

nmcli connection add type ethernet ifname eth1 con-name "PRINTER-NET" ipv4.method manual ipv4.addresses 192.168.22.1/24 connection.autoconnect yes
nmcli connection up "PRINTER-NET"

# Konfigurace DHCP serveru - definice rozsahu IP adres pro eth1 a fixní IP dle MAC
echo "Konfiguruji DHCP server (/etc/dhcp/dhcpd.conf)..."
cat <<EOF > /etc/dhcp/dhcpd.conf
subnet 192.168.22.0 netmask 255.255.255.0 {
  range 192.168.22.10 192.168.22.50;
  option routers 192.168.22.1;
  option domain-name-servers 8.8.8.8;

  # Zde nahraďte MAC adresy (XX:XX:XX:XX:XX:XX) za skutečné MAC adresy vašich tiskáren
  # Hlavni stul
  host mk3-5-lack {
    hardware ethernet XX:XX:XX:XX:XX:XX;
    fixed-address 192.168.22.11;
  }

  host prusa-xl {
    hardware ethernet XX:XX:XX:XX:XX:XX;
    fixed-address 192.168.22.12;
  }

  host mk4 {
    hardware ethernet XX:XX:XX:XX:XX:XX;
    fixed-address 192.168.22.13;
  }

  host mk3-5s-mmu {
    hardware ethernet XX:XX:XX:XX:XX:XX;
    fixed-address 192.168.22.14;
  }

  # Na kraji
  host mk3-5s-kraj {
    hardware ethernet XX:XX:XX:XX:XX:XX;
    fixed-address 192.168.22.15;
  }

  host prusa-mini {
    hardware ethernet XX:XX:XX:XX:XX:XX;
    fixed-address 192.168.22.16;
  }
}
EOF

# Nastavení, aby DHCP server poslouchal na eth1
echo "Nastavuji DHCP server na rozhraní eth1..."
sed -i 's/^INTERFACESv4=.*/INTERFACESv4="eth1"/' /etc/default/isc-dhcp-server || echo 'INTERFACESv4="eth1"' >> /etc/default/isc-dhcp-server

# Vytvoření systemd override pro isc-dhcp-server (závislost na NetworkManager a automatický restart)
echo "Vytvářím override pro isc-dhcp-server..."
mkdir -p /etc/systemd/system/isc-dhcp-server.service.d/
cat <<EOF > /etc/systemd/system/isc-dhcp-server.service.d/override.conf
[Unit]
After=NetworkManager.service
Wants=NetworkManager.service
StartLimitIntervalSec=0

[Service]
Restart=on-failure
RestartSec=5s
EOF

systemctl daemon-reload
systemctl enable isc-dhcp-server
systemctl restart isc-dhcp-server

# Povolení IP forwarding (směrování paketů) v jádře
echo "Povoluji IP forwarding..."
sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

# Nastavení NAT mezi eth0 (připojení k síti) a eth1 (lokální síť)
echo "Nastavuji NAT mezi eth0 a eth1..."
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Uložení iptables pravidel, aby přetrvala restart
netfilter-persistent save

# Konfigurace nginx jako reverzní proxy pro tiskárny
echo "Konfiguruji nginx pro reverzní proxy tiskáren..."

cat <<EOF > /etc/nginx/sites-available/printers
# Společná konfigurace pro proxy
proxy_set_header Host \$host;
proxy_set_header X-Real-IP \$remote_addr;
proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto \$scheme;
proxy_set_header Authorization \$http_authorization;
proxy_redirect off;

server {
    listen 9091;
    server_name _;
    location / { proxy_pass http://192.168.22.11/; } # MK3.5 Lack
}

server {
    listen 9092;
    server_name _;
    location / { proxy_pass http://192.168.22.12/; } # XL
}

server {
    listen 9093;
    server_name _;
    location / { proxy_pass http://192.168.22.13/; } # MK4
}

server {
    listen 9094;
    server_name _;
    location / { proxy_pass http://192.168.22.14/; } # MK3.5S MMU
}

server {
    listen 9095;
    server_name _;
    location / { proxy_pass http://192.168.22.15/; } # MK3.5S Kraj
}

server {
    listen 9096;
    server_name _;
    location / { proxy_pass http://192.168.22.16/; } # Mini
}
EOF

# Aktivace nové konfigurace (a smazání výchozí, pokud existuje a zavazí)
ln -sf /etc/nginx/sites-available/printers /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Otestování konfigurace nginx
echo "Testuji konfiguraci nginx..."
nginx -t

# Zapnutí a restart nginx
echo "Restartuji nginx..."
systemctl enable nginx
systemctl restart nginx

echo "Konfigurace dokončena. Systém je připraven k použití."