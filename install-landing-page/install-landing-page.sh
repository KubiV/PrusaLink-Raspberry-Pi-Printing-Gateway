#!/bin/bash

# =========================================================================
# Skript pro instalaci výchozí statické HTML stránky (rozcestníku) do nginx
# =========================================================================

# Zastaví vykonávání skriptu, pokud narazí na jakoukoliv chybu
set -e

# 1. Kontrola oprávnění - Skript manipuluje se systémovými složkami webserveru
# Proměnná $EUID obsahuje číslo uživatele spouštějícího skript (root má vždy 0)
if [[ $EUID -ne 0 ]]; then
   echo "Chyba: Tento skript musí být spuštěn jako root (použijte sudo bash install-landing-page.sh)." 
   exit 1
fi

echo "Začínám instalaci Landing Page (rozcestníku)..."

# 2. Definice proměnných
# Standardní kořenový adresář pro webové servery v Debian systémech (tedy i Raspberry Pi OS)
WEB_DIR="/var/www/html"

# 3. Vytvoření cílové složky
# Ověříme, zda složka existuje (-d). Pokud ne, vytvoříme ji pomocí mkdir -p (což vytvoří i případné podadresáře)
if [ ! -d "$WEB_DIR" ]; then
    echo "Adresář $WEB_DIR neexistuje, vytvářím..."
    mkdir -p "$WEB_DIR"
fi

# 4. Kontrola existence zdrojového souboru index.html
# Ověříme, zda soubor existuje v téže složce, odkud spouštíme skript (-f)
if [ ! -f "./index.html" ]; then
    echo "Kritická chyba: Soubor index.html nebyl nalezen ve stejném adresáři jako tento skript."
    exit 1
fi

# 5. Zkopírování souboru na správné místo
echo "Kopíruji index.html do $WEB_DIR..."
cp ./index.html "$WEB_DIR/index.html"

# 6. Nastavení zabezpečení a vlastnictví
# Nginx běžně operuje pod systémovým uživatelem 'www-data'
# chown - mění vlastníka souboru
chown www-data:www-data "$WEB_DIR/index.html"
# chmod 644 - Vlastník (www-data) má právo číst a psát, skupina a ostatní mají právo pouze číst
chmod 644 "$WEB_DIR/index.html"

# 7. Restart Nginx
# Restart je nutný, aby nginx vymazal mezipaměť (cache) a načetl nový soubor index.html
echo "Restartuji webový server nginx pro aplikování změn..."
systemctl restart nginx

# 8. Závěrečná informace
echo "======================================================"
echo "Instalace úvodní stránky (rozcestníku) byla dokončena!"
echo "Nyní otevřete IP adresu (nebo doménové jméno) Raspberry Pi"
echo "v prohlížeči, abyste stránku viděli."
echo "======================================================"

exit 0