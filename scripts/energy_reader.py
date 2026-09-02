#!/usr/bin/env python3
"""
Drimain Energy Reader - Odczyt miernika energii Modbus TCP
Wyślij dane do Drimain API
"""

import os
import requests
import time
import logging
from datetime import datetime

# ===== KONFIGURACJA =====
# Zmień te wartości na swoje!

DRIMAIN_API_URL = os.getenv("DRIMAIN_API_URL", "https://mergeddrimain-production.up.railway.app/api/energia/readings")
DRIMAIN_API_KEY = os.getenv("ENERGY_INGEST_KEY", "")
MASZYNA_ID = int(os.getenv("MASZYNA_ID", "1"))

# Transport: rtu (RS485 USB) or tcp (Modbus TCP gateway)
MODBUS_MODE = os.getenv("MODBUS_MODE", "rtu").strip().lower()

# Typ miernika
METER_TYPE = os.getenv("METER_TYPE", "SDM630")  # SDM630, SDM120, Eastron, Victron
METER_IP = os.getenv("METER_IP", "192.168.1.50")
METER_PORT = int(os.getenv("METER_PORT", "502"))
METER_SLAVE_ID = int(os.getenv("METER_SLAVE_ID", "1"))

# RS485 USB (Modbus RTU)
SERIAL_PORT = os.getenv("SERIAL_PORT", "/dev/ttyUSB0")
BAUD_RATE = int(os.getenv("BAUD_RATE", "9600"))
PARITY = os.getenv("PARITY", "N").upper()
STOP_BITS = int(os.getenv("STOP_BITS", "1"))
BYTE_SIZE = int(os.getenv("BYTE_SIZE", "8"))

# Optional custom register map (2 registers per float32, index in read block)
REG_VOLTAGE_IDX = int(os.getenv("REG_VOLTAGE_IDX", "0"))
REG_CURRENT_IDX = int(os.getenv("REG_CURRENT_IDX", "6"))
REG_POWER_IDX = int(os.getenv("REG_POWER_IDX", "12"))
REG_ENERGY_TOTAL_IDX = int(os.getenv("REG_ENERGY_TOTAL_IDX", "72"))

# Optional demo mode when meter is not connected yet.
DEMO_MODE = os.getenv("DEMO_MODE", "false").lower() in ("1", "true", "yes", "on")

# Interwał odczytu (sekundy)
READ_INTERVAL = int(os.getenv("READ_INTERVAL", "5"))

# ===== KONIEC KONFIGURACJI =====

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

try:
    # pymodbus 2.x
    from pymodbus.client.sync import ModbusTcpClient
    from pymodbus.client.sync import ModbusSerialClient
    from pymodbus.exceptions import ConnectionException
    MODBUS_AVAILABLE = True
    MODBUS_API = "2.x"
except ImportError:
    try:
        # pymodbus 3.x
        from pymodbus.client import ModbusTcpClient
        from pymodbus.client import ModbusSerialClient
        from pymodbus.exceptions import ConnectionException
        MODBUS_AVAILABLE = True
        MODBUS_API = "3.x"
    except ImportError:
        logger.warning("pymodbus nie zainstalowany - zainstaluj: pip install pymodbus")
        MODBUS_AVAILABLE = False
        MODBUS_API = "none"


class EnergyMeterReader:
    """Czytnik miernika energii przez Modbus TCP"""

    def __init__(self):
        self.client = None
        self.connection_attempts = 0
        self.last_error = None
        if MODBUS_AVAILABLE:
            self.connect()

    def connect(self):
        """Połączenie z miernikiem"""
        try:
            if MODBUS_MODE == "rtu":
                self.client = ModbusSerialClient(
                    method="rtu",
                    port=SERIAL_PORT,
                    baudrate=BAUD_RATE,
                    parity=PARITY,
                    stopbits=STOP_BITS,
                    bytesize=BYTE_SIZE,
                    timeout=3,
                )
            else:
                self.client = ModbusTcpClient(
                    host=METER_IP,
                    port=METER_PORT,
                    timeout=3,
                )
            if self.client.connect():
                if MODBUS_MODE == "rtu":
                    logger.info(f"✓ Połączenie z miernikiem RS485 {SERIAL_PORT} slave={METER_SLAVE_ID}")
                else:
                    logger.info(f"✓ Połączenie z miernikiem TCP {METER_IP}:{METER_PORT}")
                self.connection_attempts = 0
                return True
            else:
                raise Exception("Nie można nawiązać połączenia")
        except Exception as e:
            self.connection_attempts += 1
            self.last_error = str(e)
            if self.connection_attempts >= 3:
                if MODBUS_MODE == "rtu":
                    logger.error(f"✗ Brak połączenia z miernikiem RS485 ({SERIAL_PORT}) próba {self.connection_attempts}: {e}")
                else:
                    logger.error(f"✗ Brak połączenia z miernikiem TCP (próba {self.connection_attempts}): {e}")
            return False

    def read_registers(self, start_addr, count):
        """Odczyt rejestrów Modbus"""
        if not self.client or not MODBUS_AVAILABLE:
            return None

        try:
            # pymodbus 2.x uses unit=..., 3.x uses slave=...
            kwargs = {
                "address": start_addr,
                "count": count,
                "unit": METER_SLAVE_ID,
            }
            if MODBUS_API == "3.x":
                kwargs = {
                    "address": start_addr,
                    "count": count,
                    "slave": METER_SLAVE_ID,
                }

            result = self.client.read_holding_registers(**kwargs)
            if not result.isError():
                return result.registers
        except ConnectionException:
            logger.warning("⚠ Utrata połączenia z miernikiem")
            self.connect()
        except Exception as e:
            logger.debug(f"Błąd odczytu: {e}")

        return None

    def regs_to_float(self, regs, start_idx):
        """Konwersja 2x16-bit (big endian) → float32"""
        if not regs or len(regs) <= start_idx + 1:
            return 0.0
        high = regs[start_idx]
        low = regs[start_idx + 1]
        import struct
        val = (high << 16) | low
        return struct.unpack('>f', struct.pack('>I', val))[0]

    def read_energy_data(self):
        """Odczyt danych energii dla różnych typów mierników"""
        if DEMO_MODE:
            logger.info("[DEMO_MODE] Wysylam dane testowe")
            return self._dummy_data()

        if not MODBUS_AVAILABLE:
            logger.warning("⚠ Modbus niedostępny - zwracam dane testowe")
            return self._dummy_data()

        regs = self.read_registers(start_addr=0, count=100)
        if not regs:
            return None

        try:
            if METER_TYPE in ["SDM630", "SDM120"]:
                # Adresy dla Eastron SDM630/120
                voltage_v = self.regs_to_float(regs, 0)    # Reg 0-1: Napięcie L1
                current_a = self.regs_to_float(regs, 6)    # Reg 6-7: Prąd L1
                power_kw = self.regs_to_float(regs, 12) / 1000  # Reg 12-13: Moc P / 1000
                power_va = self.regs_to_float(regs, 16) / 1000  # VA
                power_var = self.regs_to_float(regs, 18) / 1000  # VAR
                energy_kwh_total = self.regs_to_float(regs, 72)  # Reg 72-73: Energia łączna

            elif METER_TYPE == "Victron":
                # Adresy dla Victron
                voltage_v = self.regs_to_float(regs, 12)
                current_a = self.regs_to_float(regs, 26)
                power_kw = self.regs_to_float(regs, 34) / 1000
                energy_kwh_total = self.regs_to_float(regs, 58)

            else:
                # Generic/Lumel fallback with env-configurable register indexes.
                voltage_v = self.regs_to_float(regs, REG_VOLTAGE_IDX)
                current_a = self.regs_to_float(regs, REG_CURRENT_IDX)
                power_kw = self.regs_to_float(regs, REG_POWER_IDX) / 1000
                energy_kwh_total = self.regs_to_float(regs, REG_ENERGY_TOTAL_IDX)

            return {
                "voltageV": round(voltage_v, 1),
                "currentA": round(current_a, 2),
                "powerKw": round(power_kw, 2),
                "energyKwhTotal": round(energy_kwh_total, 1)
            }
        except Exception as e:
            logger.error(f"✗ Błąd konwersji danych: {e}")
            return None

    def _dummy_data(self):
        """Dane testowe (dla demo bez miernika)"""
        import random
        return {
            "voltageV": round(230 + random.uniform(-5, 5), 1),
            "currentA": round(10 + random.uniform(-2, 2), 2),
            "powerKw": round(2.5 + random.uniform(-0.5, 0.5), 2),
            "energyKwhTotal": round(1000 + random.uniform(0, 5), 1)
        }

    def send_to_api(self, data):
        """Wysłanie danych do Drimain API"""
        payload = {
            "maszynaId": MASZYNA_ID,
            "deviceId": self._device_id(),
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
                logger.info(f"✓ API OK | P={data['powerKw']:.1f}kW | E={data['energyKwhTotal']:.1f}kWh | U={data['voltageV']:.0f}V | I={data['currentA']:.1f}A")
                return True
            else:
                logger.error(f"✗ API error {response.status_code}: {response.text[:100]}")
                if response.status_code == 403:
                    logger.error("  ⚠ API KEY nieprawidłowy!")
                return False
        except requests.exceptions.Timeout:
            logger.warning(f"⚠ Timeout przy wysłaniu do {DRIMAIN_API_URL}")
            return False
        except requests.exceptions.ConnectionError:
            logger.warning(f"⚠ Brak połączenia z {DRIMAIN_API_URL}")
            return False
        except Exception as e:
            logger.error(f"✗ Błąd wysyłania: {e}")
            return False

    def run(self):
        """Główna pętla"""
        logger.info("=" * 60)
        logger.info(f"🚀 Drimain Energy Reader")
        logger.info(f"   API: {DRIMAIN_API_URL}")
        logger.info(f"   Modbus API: {MODBUS_API}")
        logger.info(f"   Modbus mode: {MODBUS_MODE}")
        if MODBUS_MODE == "rtu":
            logger.info(f"   Miernik: {METER_TYPE} @ {SERIAL_PORT} (baud={BAUD_RATE}, parity={PARITY}, stop={STOP_BITS}, bytes={BYTE_SIZE}, slave={METER_SLAVE_ID})")
        else:
            logger.info(f"   Miernik: {METER_TYPE} @ {METER_IP}:{METER_PORT} (slave={METER_SLAVE_ID})")
        logger.info(f"   Demo mode: {'ON' if DEMO_MODE else 'OFF'}")
        logger.info(f"   Maszyna ID: {MASZYNA_ID}")
        logger.info(f"   Interwał: {READ_INTERVAL}s")
        logger.info("=" * 60)

        if not DRIMAIN_API_KEY:
            logger.error("✗ Brak ENERGY_INGEST_KEY (ustaw zmienna srodowiskowa)")
            return

        if MODBUS_MODE not in ("rtu", "tcp"):
            logger.error("✗ Nieprawidlowy MODBUS_MODE. Uzyj: rtu lub tcp")
            return

        error_count = 0
        success_count = 0

        while True:
            try:
                data = self.read_energy_data()
                if data:
                    if self.send_to_api(data):
                        success_count += 1
                        error_count = 0
                    else:
                        error_count += 1
                else:
                    error_count += 1
                    logger.warning(f"⚠ Nie udało się odczytać miernika (błędy: {error_count})")

                time.sleep(READ_INTERVAL)

            except KeyboardInterrupt:
                logger.info("\n⏹ Zatrzymanie (Ctrl+C)")
                logger.info(f"   Pomyślnych: {success_count}")
                break
            except Exception as e:
                logger.error(f"✗ Nieoczekiwany błąd: {e}")
                error_count += 1
                time.sleep(5)

    def _device_id(self):
        if MODBUS_MODE == "rtu":
            return f"rpi-rs485-{SERIAL_PORT.split('/')[-1]}-s{METER_SLAVE_ID}"
        return f"rpi-{METER_IP}-s{METER_SLAVE_ID}"


if __name__ == "__main__":
    reader = EnergyMeterReader()
    reader.run()

