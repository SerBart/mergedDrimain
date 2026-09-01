# Instrukcja wdrożenia Drimain na Raspberry Pi

## 🎯 Ogólny plan

Raspberry Pi będzie uruchamiać:
1. **Skrypt Python** - odczytujący dane z miernika energii (MQTT/HTTP)
2. **Wysyłanie danych** do Drimain API za pomocą X-API-KEY

---

## 📋 Wymagania sprzętowe

- **Model**: Raspberry Pi 4B (minimum 2GB RAM) lub Raspberry Pi 5
- **System**: Raspberry Pi OS (64-bit zalecane)
- **Połączenie**: Ethernet lub WiFi
- **Miernik energii**: SDM630, Eastron, Victron itp. (komunikacja Modbus TCP/RTU, MQTT lub HTTP)

---

## 🔧 Krok 1: Przygotowanie Raspberry Pi

### 1.1 Aktualizacja systemu
```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y python3-pip python3-venv
```

### 1.2 Instalacja Python i bibliotek
```bash
# Utwórz katalog dla apki
mkdir -p ~/drimain
cd ~/drimain

# Utwórz virtual environment
python3 -m venv venv
source venv/bin/activate

# Zainstaluj wymagane pakiety
pip install requests pymodbus paho-mqtt schedule
```

---

## 📡 Krok 2: Skrypt Python do odczytywania miernika

Utwórz plik `energy_reader.py`:

```python
#!/usr/bin/env python3
import requests
import json
import time
import logging
from datetime import datetime
from pymodbus.client.sync import ModbusTcpClient
from pymodbus.exceptions import ConnectionException

# Konfiguracja loggowania
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ===== KONFIGURACJA =====
# Zmień te wartości!
DRIMAIN_API_URL = "http://192.168.1.100:8080/api/energia/readings"  # IP lub domena Drimain
DRIMAIN_API_KEY = "twoj-super-tajny-klucz"  # Ustaw w application.yml app.energy.ingest-key
MASZYNA_ID = 1  # ID maszyny z bazy Drimain

# Konfiguracja miernika Modbus TCP
METER_IP = "192.168.1.50"
METER_PORT = 502
METER_SLAVE_ID = 1

# Interwał odczytu (sekundy)
READ_INTERVAL = 15

# ===== KONIEC KONFIGURACJI =====

class EnergyMeterReader:
    def __init__(self):
        self.client = None
        self.connect()

    def connect(self):
        """Połączenie z miernikiem"""
        try:
            self.client = ModbusTcpClient(
                host=METER_IP,
                port=METER_PORT,
                method='rtu',
                stopbits=1,
                bytesize=8,
                parity='N',
                baudrate=9600,
                timeout=3
            )
            logger.info("✓ Połączenie z miernikiem nawiązane")
            return True
        except Exception as e:
            logger.error(f"✗ Błąd połączenia z miernikiem: {e}")
            return False

    def read_registers(self, start_addr, count):
        """Odczyt rejestrów Modbus"""
        try:
            result = self.client.read_holding_registers(
                address=start_addr,
                count=count,
                unit=METER_SLAVE_ID
            )
            if result.isError():
                return None
            return result.registers
        except ConnectionException:
            logger.warning("⚠ Utrata połączenia z miernikiem, próba ponownego")
            self.connect()
            return None
        except Exception as e:
            logger.error(f"✗ Błąd odczytu: {e}")
            return None

    def read_energy_data(self):
        """Odczyt danych energii"""
        # Rejestr Modbus 40001-40100 (dla SDM630)
        # Dostosuj do swojego miernika!
        
        regs = self.read_registers(start_addr=0, count=100)
        if not regs:
            return None

        try:
            # Konwersja 2x16-bit → float32 (big endian)
            def regs_to_float(start_idx):
                high = regs[start_idx]
                low = regs[start_idx + 1]
                return float((high << 16) | low) / 1000.0  # /1000 dla niektórych mierników

            # Adresy dla SDM630 - zmień wg dokumentacji twojego miernika!
            voltage_v = regs_to_float(0)      # Napięcie fazy 1
            current_a = regs_to_float(2)      # Prąd fazy 1
            power_kw = regs_to_float(4) / 1000.0  # Moc
            energy_kwh_total = regs_to_float(50)  # Energia łączna

            return {
                "voltageV": voltage_v,
                "currentA": current_a,
                "powerKw": power_kw,
                "energyKwhTotal": energy_kwh_total
            }
        except Exception as e:
            logger.error(f"✗ Błąd konwersji danych: {e}")
            return None

    def send_to_api(self, data):
        """Wysłanie danych do Drimain API"""
        payload = {
            "maszynaId": MASZYNA_ID,
            "deviceId": f"rpi-{METER_IP}",
            "recordedAt": datetime.utcnow().isoformat() + "Z",
            "voltageV": data.get("voltageV"),
            "currentA": data.get("currentA"),
            "powerKw": data.get("powerKw"),
            "energyKwhTotal": data.get("energyKwhTotal")
        }

        try:
            headers = {
                "X-API-KEY": DRIMAIN_API_KEY,
                "Content-Type": "application/json"
            }
            response = requests.post(
                DRIMAIN_API_URL,
                json=payload,
                headers=headers,
                timeout=5
            )
            
            if response.status_code == 201:
                logger.info(f"✓ Dane wysłane: P={data['powerKw']:.1f}kW, E={data['energyKwhTotal']:.1f}kWh")
                return True
            else:
                logger.error(f"✗ API error {response.status_code}: {response.text}")
                return False
        except requests.exceptions.RequestException as e:
            logger.error(f"✗ Błąd wysyłania: {e}")
            return False

    def run(self):
        """Główna pętla"""
        logger.info(f"🚀 Uruchamianie odczytywania energii (interwał: {READ_INTERVAL}s)")
        
        while True:
            try:
                data = self.read_energy_data()
                if data:
                    self.send_to_api(data)
                
                time.sleep(READ_INTERVAL)
            except KeyboardInterrupt:
                logger.info("⏹ Zatrzymanie...")
                break
            except Exception as e:
                logger.error(f"✗ Nieoczekiwany błąd: {e}")
                time.sleep(5)

if __name__ == "__main__":
    reader = EnergyMeterReader()
    reader.run()
```

---

## 🌐 Krok 3: Alternatywa - MQTT (dla mierników z MQTT)

Jeśli Twój miernik ma MQTT, użyj `energy_reader_mqtt.py`:

```python
#!/usr/bin/env python3
import paho.mqtt.client as mqtt
import requests
import json
import logging
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# KONFIGURACJA
DRIMAIN_API_URL = "http://192.168.1.100:8080/api/energia/readings"
DRIMAIN_API_KEY = "twoj-klucz"
MASZYNA_ID = 1

MQTT_BROKER = "192.168.1.50"
MQTT_PORT = 1883
MQTT_TOPIC = "energy/meter/+/data"  # Dostosuj do twojego miernika

def on_message(client, userdata, msg):
    try:
        data = json.loads(msg.payload)
        
        payload = {
            "maszynaId": MASZYNA_ID,
            "deviceId": f"mqtt-{msg.topic}",
            "recordedAt": datetime.utcnow().isoformat() + "Z",
            "voltageV": data.get("voltage"),
            "currentA": data.get("current"),
            "powerKw": data.get("power"),
            "energyKwhTotal": data.get("energy_total")
        }
        
        headers = {"X-API-KEY": DRIMAIN_API_KEY, "Content-Type": "application/json"}
        resp = requests.post(DRIMAIN_API_URL, json=payload, headers=headers, timeout=5)
        
        if resp.status_code == 201:
            logger.info(f"✓ MQTT: {data.get('power')}kW")
        else:
            logger.error(f"✗ API error: {resp.status_code}")
    except Exception as e:
        logger.error(f"✗ Błąd: {e}")

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        logger.info("✓ MQTT connected")
        client.subscribe(MQTT_TOPIC)
    else:
        logger.error(f"✗ MQTT error code {rc}")

client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

client.connect(MQTT_BROKER, MQTT_PORT, 60)
client.loop_forever()
```

---

## 🔑 Krok 4: Konfiguracja Drimain API KEY

### Na serwerze Drimain:

Edytuj `src/main/resources/application.yml`:

```yaml
app:
  energy:
    ingest-key: "twoj-super-tajny-klucz-64-znaki"  # Wygeneruj losowy string
```

**LUB** zmienną środowiskową:
```bash
export APP_ENERGY_INGEST_KEY="twoj-super-tajny-klucz"
java -jar driMain-1.0.0.jar
```

---

## 🐳 Krok 5: Uruchomienie jako serwis systemd

Utwórz `/etc/systemd/system/drimain-energy.service`:

```ini
[Unit]
Description=Drimain Energy Reader
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/drimain
ExecStart=/home/pi/drimain/venv/bin/python3 /home/pi/drimain/energy_reader.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Włączenie serwisu:
```bash
sudo systemctl daemon-reload
sudo systemctl enable drimain-energy
sudo systemctl start drimain-energy
```

### Logi:
```bash
sudo journalctl -u drimain-energy -f
```

---

## 📊 Krok 6: Monitorowanie

### Sprawdzenie statusu:
```bash
sudo systemctl status drimain-energy
```

### Testowe wysłanie danych:
```bash
curl -X POST http://localhost:8080/api/energia/readings \
  -H "X-API-KEY: twoj-klucz" \
  -H "Content-Type: application/json" \
  -d '{
    "maszynaId": 1,
    "deviceId": "test-rpi",
    "recordedAt": "2026-08-31T10:00:00Z",
    "powerKw": 2.5,
    "energyKwhTotal": 150.5,
    "voltageV": 230,
    "currentA": 10.8
  }'
```

---

## 🐛 Troubleshooting

### Problem: Brak połączenia z miernikiem
```bash
# Test połączenia
python3 -c "from pymodbus.client.sync import ModbusTcpClient; c = ModbusTcpClient('192.168.1.50'); print('OK' if c.connect() else 'FAIL')"
```

### Problem: API error 403
- Sprawdź czy X-API-KEY jest poprawny
- Sprawdź czy klucz jest ustawiony w `application.yml`

### Problem: Złe wartości z miernika
- Sprawdź dokumentację miernika na adresy rejestrów Modbus
- Pobierz wartości ręcznie za pomocą: `pymodbus-console 192.168.1.50`

### Problem: Serwis nie startuje
```bash
sudo journalctl -u drimain-energy -n 50  # Ostatnie 50 linii logów
```

---

## 📱 Weryfikacja w aplikacji

1. Zaloguj się do Drimain Web UI (http://serwer:8080)
2. Przejdź do **Energia** → **Przegląd**
3. Powinnaś zobaczyć dane z Raspberry Pi w "Aktualnym zużyciu"
4. Włącz **SSE streaming** - dane będą aktualizować się automatycznie co 15-30 sekund

---

## 🔄 Automatyczne restartowanie po utracie sieci

Edytuj `/etc/systemd/system/drimain-energy.service`:

```ini
[Service]
...
RestartSec=30
Environment="PYTHONUNBUFFERED=1"
```

---

## 📦 Backup konfiguracji

```bash
# Backup skryptów
tar -czf drimain_backup.tar.gz /home/pi/drimain/
scp drimain_backup.tar.gz user@backup-server:/backups/
```

---

## 🚀 Rozwinięcia

### Wiele mierników
Utwórz osobne serwisy:
```bash
# Serwis 1
sudo systemctl start drimain-energy@meter1
# Serwis 2
sudo systemctl start drimain-energy@meter2
```

### Integracja z InfluxDB (opcjonalnie)
Dodaj do skryptu:
```python
from influxdb import InfluxDBClient

client = InfluxDBClient(host='localhost', port=8086)
client.switch_database('energy')
client.write_points([{
    "measurement": "power",
    "fields": {"value": power_kw}
}])
```

---

## 📧 Troubleshooting z supportem

Jeśli masz problemy, zbierz:
1. `sudo journalctl -u drimain-energy > /tmp/logs.txt`
2. Wersja Python: `python3 --version`
3. Test połączenia: `curl -v http://DRIMAIN_URL/api/energia/overview`
4. Konfiguracja miernika (typ, model, IP)

---

**Happy monitoring! 🎉**

