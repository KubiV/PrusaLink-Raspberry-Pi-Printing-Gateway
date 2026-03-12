# Debugování a řešení problémů - PrusaLink-Raspberry-Pi-Printing-Gateway

Tento dokument slouží jako praktický průvodce pro debugování a řešení běžných problémů při nastavování a provozu Raspberry Pi jako brány pro ovládání 3D tiskáren.

---

## 1. Nastavení IP adresy a sítě s NetworkManagerem (nmcli)

Správa sítě na eth1 je nyní plně v režii NetworkManageru. Pokud síťové rozhraní `eth1` nemá správnou IP adresu (192.168.22.1) nebo není aktivní:

- Ověřte stav rozhraní a aktivních připojení:

  ```bash
  ip a show eth1
  nmcli connection show
  ```

Pokud spojení chybí, má špatnou IP adresu nebo nefunguje, nejsnazší cestou je stará spojení smazat a vytvořit nové:

```bash
sudo nmcli connection delete eth1
sudo nmcli connection delete ethernet-eth1
sudo nmcli connection delete "PRINTER-NET"

sudo nmcli connection add type ethernet ifname eth1 con-name "PRINTER-NET" ipv4.method manual ipv4.addresses 192.168.22.1/24 connection.autoconnect yes

sudo nmcli connection up "PRINTER-NET"
```

## 2. Nastavení připojení k internetu a směrování
Pokud se potřebujete připojit na místní WiFi nebo debugovat směrování do internetu:

Pro připojení k WiFi můžete využít grafické rozhraní v terminálu:

```bash
sudo nmtui
```

Nebo se připojit přímo příkazem (nahraďte název a heslo):

```bash
sudo nmcli device wifi connect "NazevSite" password "HesloSite"
```

Ověřte nastavení tras (zda máte správně nastavenou defaultní bránu):

```bash
ip route show
```

## 3. Kontrola připojených tiskáren

### a) Záznamy z DHCP serveru:

Pro rychlý výpis přiřazených IP adres a spárovaných MAC adres použijte:

```bash
grep -E "lease|hardware|hostname" /var/lib/dhcp/dhcpd.leases
```

Případně si vypište celý soubor:

```bash
cat /var/lib/dhcp/dhcpd.leases
```

### b) Nmap - síťové skenování:

Prohledá celou novou podsíť a zobrazí aktivní zařízení:

```bash
sudo apt install nmap
nmap -sn 192.168.22.0/24
```

### c) arp-scan - detailnější sken:

Ukáže MAC adresy a IP zařízení fyzicky připojených na rozhraní eth1:

```bash
sudo apt install arp-scan
sudo arp-scan --interface=eth1 --localnet
```

## 4. DHCP server (isc-dhcp-server)

Stav a restart DHCP serveru:

```bash
sudo systemctl status isc-dhcp-server
sudo systemctl restart isc-dhcp-server
```

Promazání cache DHCP: Pokud DHCP server přiděluje špatné IP adresy i po úpravě konfigurace, promažte soubor s historií výpůjček (leases):

```bash
sudo systemctl stop isc-dhcp-server
sudo rm /var/lib/dhcp/dhcpd.leases
sudo touch /var/lib/dhcp/dhcpd.leases
sudo systemctl start isc-dhcp-server
```

Upozornění: DHCP server běží s vytvořeným systemd override (/etc/systemd/system/isc-dhcp-server.service.d/override.conf), aby čekal na NetworkManager a v případě selhání se sám restartoval. Pokud upravujete spouštění služeb, nezapomeňte aplikovat změny pomocí `sudo systemctl daemon-reload`.

## 5. Kontrola iptables a NAT

Zobrazte aktuální pravidla NAT:

```bash
sudo iptables -t nat -L -n -v
```

Ujistěte se, že existuje pravidlo pro masquerading na rozhraní připojeném do sítě (obvykle eth0 nebo wlan0):

```
POSTROUTING  all  --  anywhere  anywhere  MASQUERADE  dev eth0
```

Pokud pravidlo chybí, přidejte jej (upravte eth0 dle potřeby) a trvale uložte:

```bash
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo netfilter-persistent save
```

## 6. Kontrola nginx proxy

Tiskárny mají nyní konfiguraci v `/etc/nginx/sites-available/printers`.

Otestujte, zda neobsahuje překlepy:

```bash
sudo nginx -t
```

Po změně konfigurace ji aplikujte:

```bash
sudo systemctl reload nginx
```

Nebo službu zcela restartujte:

```bash
sudo systemctl restart nginx
```

Pokud proxy nefunguje a stránky se nenačítají (porty 9091-9096), zkontrolujte logy Nginxu:

```bash
sudo journalctl -u nginx
```

## 7. Obecné tipy

- Zkontrolujte, zda máte správně nastaveny IP adresy (síť 192.168.22.x).
- Ujistěte se, že je povolen IP forwarding: `sysctl net.ipv4.ip_forward` by mělo vrátit `net.ipv4.ip_forward = 1`.
- Pro ověření komunikace pošlete z Raspberry Pi ping přímo na statickou adresu tiskárny (např. `ping 192.168.22.12`).
- Ujistěte se, že VPN tunel je aktivní a směruje provoz na správnou IP adresu Raspberry Pi v nadřazené síti.