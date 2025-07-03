#!/bin/bash

# Script pro instalaci výchozí HTML stránky do nginx

# Kontrola spuštění s root oprávněním
if [[ $EUID -ne 0 ]]; then
   echo "Tento skript musí být spuštěn jako root." 
   exit 1
fi

# Cílová složka pro webové soubory nginx
WEB_DIR="/var/www/html"

# Kontrola existence složky
if [ ! -d "$WEB_DIR" ]; then
    echo "Adresář $WEB_DIR neexistuje, vytvářím..."
    mkdir -p "$WEB_DIR"
fi

# Kopírování index.html (předpokládá se, že je ve stejné složce jako skript)
if [ ! -f "./index.html" ]; then
    echo "Soubor index.html nebyl nalezen ve stejném adresáři jako skript."
    exit 1
fi

cp ./index.html "$WEB_DIR/"

# Nastavení oprávnění
chown www-data:www-data "$WEB_DIR/index.html"
chmod 644 "$WEB_DIR/index.html"

# Restart nginx pro načtení změn
echo "Restartuji nginx..."
systemctl restart nginx

echo "Instalace úvodní stránky byla dokončena."
echo "Nyní otevřete IP adresu Raspberry Pi v prohlížeči, abyste stránku viděli."
