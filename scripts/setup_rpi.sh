#!/bin/bash
# Szybka konfiguracja Drimain na Raspberry Pi
# Uruchom: bash setup_rpi.sh

set -e

echo "════════════════════════════════════════════"
echo "  Drimain Raspberry Pi - Setup"
echo "════════════════════════════════════════════"

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Katalog instalacji
INSTALL_DIR="/home/pi/drimain"
SCRIPT_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${YELLOW}[1/5] Aktualizacja systemu...${NC}"
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y python3-pip python3-venv git

echo -e "${YELLOW}[2/5] Tworzenie katalogów...${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo -e "${YELLOW}[3/5] Tworzenie Python virtual environment...${NC}"
python3 -m venv venv
source venv/bin/activate

echo -e "${YELLOW}[4/5] Instalacja zależności...${NC}"
pip install --upgrade pip
pip install -r "$SCRIPT_SOURCE/requirements_rpi.txt"

echo -e "${YELLOW}[5/5] Konfiguracja serwisu systemd...${NC}"
# Kopiowanie skryptu
cp "$SCRIPT_SOURCE/energy_reader.py" "$INSTALL_DIR/energy_reader.py"
chmod +x "$INSTALL_DIR/energy_reader.py"

# Kopia service file
sudo cp "$SCRIPT_SOURCE/drimain-energy.service" /etc/systemd/system/

echo ""
echo -e "${GREEN}✓ Instalacja zakończona!${NC}"
echo ""
echo "NASTĘPNE KROKI:"
echo "────────────────────────────────────────────"
echo "1. Edytuj konfigurację:"
echo "   nano $INSTALL_DIR/energy_reader.py"
echo "   - Zmień DRIMAIN_API_URL na IP twojego serwera"
echo "   - Zmień DRIMAIN_API_KEY na klucz z application.yml"
echo "   - Zmień METER_IP na IP twojego miernika"
echo "   - Zmień MASZYNA_ID na ID z bazy"
echo ""
echo "2. Test skryptu:"
echo "   cd $INSTALL_DIR"
echo "   source venv/bin/activate"
echo "   python3 energy_reader.py"
echo ""
echo "3. Włącz serwis:"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable drimain-energy"
echo "   sudo systemctl start drimain-energy"
echo ""
echo "4. Sprawdź status:"
echo "   sudo systemctl status drimain-energy"
echo "   sudo journalctl -u drimain-energy -f"
echo ""
echo "────────────────────────────────────────────"
echo -e "${YELLOW}WAŻNE: Nie zapomnij ustawić API KEY!${NC}"
echo ""

