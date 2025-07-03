#!/bin/bash
# Skript pro nastavení Raspberry Pi jako DHCP routeru s NAT a reverzní proxy (nginx)
# pro vzdálený přístup k 3D tiskárnám přes PrusaLink.

set -e  # Ukončí skript při jakékoliv chybě

echo "Aktualizace systému..."
apt update
apt upgrade -y

# Nastavení statické IP adresy na rozhraní eth1
# Upravíme konfiguraci dhcpcd, aby eth1 mělo IP 192.168.2.1/24
echo "Nastavuji statickou IP adresu na eth1..."
cat <<EOF >> /etc/dhcpcd.conf

interface eth1
static ip_address=192.168.2.1/24
nohook wpa_supplicant
EOF

# Instalace potřebných balíčků
echo "Instaluji potřebné balíčky: nmap, isc-dhcp-server, iptables, iptables-persistent, nginx..."
apt install -y nmap isc-dhcp-server iptables iptables-persistent nginx

# Konfigurace DHCP serveru - definice rozsahu IP adres pro eth1
echo "Konfiguruji DHCP server (/etc/dhcp/dhcpd.conf)..."
cat <<EOF > /etc/dhcp/dhcpd.conf
subnet 192.168.2.0 netmask 255.255.255.0 {
  range 192.168.2.10 192.168.2.20;
  option routers 192.168.2.1;
  option domain-name-servers 8.8.8.8;
}
EOF

# Nastavení, aby DHCP server poslouchal na eth1 (důležité: správná proměnná je INTERFACESv4)
echo "Nastavuji DHCP server na rozhraní eth1..."
sed -i 's/^INTERFACESv4=.*/INTERFACESv4="eth1"/' /etc/default/isc-dhcp-server || echo 'INTERFACESv4="eth1"' >> /etc/default/isc-dhcp-server

# Restartování služeb dhcpcd a isc-dhcp-server pro načtení nových konfigurací
echo "Restartuji služby dhcpcd a isc-dhcp-server..."
systemctl restart dhcpcd
systemctl restart isc-dhcp-server

# Povolení IP forwarding (směrování paketů) v jádře
echo "Povoluji IP forwarding..."
sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1

# Nastavení NAT mezi eth0 (připojení k síti) a eth1 (lokální síť)
echo "Nastavuji NAT mezi eth0 a eth1..."
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Uložení iptables pravidel, aby přetrvala restart
netfilter-persistent save

# Konfigurace nginx jako reverzní proxy pro dvě tiskárny s IP 192.168.2.11 a 192.168.2.12 na portech 9091 a 9092
echo "Konfiguruji nginx pro reverzní proxy tiskáren..."

cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 9091;
    #server_name 192.168.137.112;  # upravte na skutečnou IP nebo hostname Pi ve vaší VPN/LAN

    location / {
        proxy_pass http://192.168.2.11/; # IP adresa tiskarny
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Authorization \$http_authorization;
        proxy_redirect off;
    }
}

server {
    listen 9092;
    #server_name 192.168.137.112;  # upravte na skutečnou IP nebo hostname Pi ve vaší VPN/LAN

    location / {
        proxy_pass http://192.168.2.12/; # IP adresa tiskarny
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Authorization \$http_authorization;
        proxy_redirect off;
    }
}
EOF

# Otestování konfigurace nginx
echo "Testuji konfiguraci nginx..."
nginx -t

# Restart nginx, aby načetl novou konfiguraci
echo "Restartuji nginx..."
systemctl restart nginx

echo "Konfigurace dokončena. Systém je připraven k použití."
