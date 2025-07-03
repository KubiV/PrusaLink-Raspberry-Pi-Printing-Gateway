
# Debugování a řešení problémů - PrusaLink-Raspberry-Pi-Printing-Gateway

Tento dokument slouží jako praktický průvodce pro debugování a řešení běžných problémů při nastavování a provozu Raspberry Pi jako brány pro ovládání 3D tiskáren.

---

## 1. Nastavení IP adresy a aktivace rozhraní eth1

Pokud síťové rozhraní `eth1` nemá správnou IP adresu nebo není aktivní, můžete použít:

```bash
sudo ip addr add 192.168.2.1/24 dev eth1
sudo ip link set eth1 up
```

- Ověřte stav rozhraní:

  ```bash
  ip addr show eth1
  ```

- Pokud IP adresu nelze přidat, zkontrolujte, zda není konflikt s jiným zařízením ve stejné síti.

---

## 2. Nastavení výchozí brány (default route)

Pro správný provoz směrování dat použijte:

```bash
sudo ip route del default
sudo ip route add default via 192.168.137.1 dev wlan0
```

- `192.168.137.1` nahraďte IP adresou vaší skutečné brány (např. WiFi routeru).
- Ověřte nastavení tras:

  ```bash
  ip route show
  ```

---

## 3. Kontrola připojených tiskáren

### a) Záznamy z DHCP serveru:

```bash
cat /var/lib/dhcp/dhcpd.leases
```

- Zobrazí seznam zařízení, kterým DHCP server přidělil IP adresu.

### b) Nmap - síťové skenování:

```bash
sudo apt install nmap
nmap -sn 192.168.2.0/24
```

- Prohledá celou podsíť a zobrazí aktivní zařízení.

### c) arp-scan - detailnější sken:

```bash
sudo apt install arp-scan
sudo arp-scan --interface=eth1 --localnet
```

- Ukáže MAC adresy a IP zařízení připojených na rozhraní `eth1`.

---

## 4. DHCP server

- Restart DHCP serveru:

  ```bash
  sudo systemctl restart isc-dhcp-server
  ```

- Stav DHCP serveru:

  ```bash
  sudo systemctl status isc-dhcp-server
  ```

- Pokud server neběží, zkontrolujte logy:

  ```bash
  journalctl -xe | grep dhcp
  ```

---

## 5. Kontrola iptables a NAT

- Zobrazte aktuální pravidla NAT:

  ```bash
  sudo iptables -t nat -L -n -v
  ```

- Ujistěte se, že existuje pravidlo pro masquerading na `eth0`:

  ```
  POSTROUTING  all  --  anywhere  anywhere  MASQUERADE  dev eth0
  ```

- Pokud ne, přidejte pravidlo znovu a uložte:

  ```bash
  sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  sudo netfilter-persistent save
  ```

---

## 6. Kontrola nginx proxy

- Otestujte konfiguraci nginx:

  ```bash
  sudo nginx -t
  ```

- Restartujte nginx:

  ```bash
  sudo systemctl restart nginx
  ```

- Pokud proxy nefunguje, zkontrolujte logy:

  ```bash
  sudo journalctl -u nginx
  ```

---

## 7. Obecné tipy

- Zkontrolujte, zda máte správně nastaveny IP adresy, subnety a brány.
- Ověřte, že všechny služby běží a nemají chyby v konfiguraci.
- Pro komunikaci s tiskárnami použijte ping nebo curl na jejich IP.
- Ujistěte se, že VPN tunel je aktivní a směruje provoz správně.

