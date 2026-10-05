#!/usr/bin/env python3
"""
Drimain Energy Reader - odczyt mierników energii przez Modbus RTU/TCP
i wysyłka danych do Drimain API.
"""

import logging
import os
import time
from dataclasses import dataclass
from datetime import datetime
from typing import List

import requests

# ===== KONFIGURACJA =====
# Zmieniaj wartosci przez /etc/drimain-energy-reader.env na Raspberry.

DRIMAIN_API_URL = os.getenv(
    "DRIMAIN_API_URL",
    "https://mergeddrimain-production.up.railway.app/api/energia/readings",
)
DRIMAIN_API_KEY = os.getenv("ENERGY_INGEST_KEY", "")
MASZYNA_ID = int(os.getenv("MASZYNA_ID", "160"))
METER_SLAVE_ID = int(os.getenv("METER_SLAVE_ID", "1"))
METER_TARGETS_RAW = os.getenv("METER_TARGETS", "").strip()

MODBUS_MODE = os.getenv("MODBUS_MODE", "rtu").strip().lower()
METER_IP = os.getenv("METER_IP", "192.168.1.50")
METER_PORT = int(os.getenv("METER_PORT", "502"))

SERIAL_PORT = os.getenv("SERIAL_PORT", "/dev/ttyUSB0")
BAUD_RATE = int(os.getenv("BAUD_RATE", "9600"))
PARITY = os.getenv("PARITY", "N").upper()
STOP_BITS = int(os.getenv("STOP_BITS", "1"))
BYTE_SIZE = int(os.getenv("BYTE_SIZE", "8"))

READ_INTERVAL = int(os.getenv("READ_INTERVAL", "5"))
DEMO_MODE = os.getenv("DEMO_MODE", "false").lower() in ("1", "true", "yes", "on")

# Domyslne indeksy rejestrow dla starszego, sprawdzonego licznika.
DEFAULT_VOLTAGE_IDX = int(os.getenv("REG_VOLTAGE_IDX", "0"))
DEFAULT_CURRENT_IDX = int(os.getenv("REG_CURRENT_IDX", "6"))
DEFAULT_POWER_IDX = int(os.getenv("REG_POWER_IDX", "12"))
DEFAULT_ENERGY_TOTAL_IDX = int(os.getenv("REG_ENERGY_TOTAL_IDX", "72"))
DEFAULT_POWER_DIVIDER = float(os.getenv("POWER_DIVIDER", "1000"))
DEFAULT_REG_FN = os.getenv("METER_REG_FN", "holding").strip().lower()

# ===== KONIEC KONFIGURACJI =====

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


try:
    # pymodbus 2.x
    from pymodbus.client.sync import ModbusSerialClient
    from pymodbus.client.sync import ModbusTcpClient
    from pymodbus.exceptions import ConnectionException

    MODBUS_AVAILABLE = True
    MODBUS_API = "2.x"
except ImportError:
    try:
        # pymodbus 3.x
        from pymodbus.client import ModbusSerialClient
        from pymodbus.client import ModbusTcpClient
        from pymodbus.exceptions import ConnectionException

        MODBUS_AVAILABLE = True
        MODBUS_API = "3.x"
    except ImportError:
        logger.warning("pymodbus nie zainstalowany - zainstaluj: pip install pymodbus")
        MODBUS_AVAILABLE = False
        MODBUS_API = "none"


@dataclass(frozen=True)
class MeterTarget:
    machine_id: int
    slave_id: int


def _parse_meter_targets(raw_value: str) -> List[MeterTarget]:
    if not raw_value:
        return [MeterTarget(machine_id=MASZYNA_ID, slave_id=METER_SLAVE_ID)]

    targets: List[MeterTarget] = []
    parts = [part.strip() for part in raw_value.replace(";", ",").split(",") if part.strip()]
    for part in parts:
        if ":" not in part:
            raise ValueError(
                f"Nieprawidłowy wpis METER_TARGETS '{part}'. Użyj formatu maszynaId:slaveId, np. 160:1,181:2"
            )
        machine_text, slave_text = [segment.strip() for segment in part.split(":", 1)]
        targets.append(MeterTarget(machine_id=int(machine_text), slave_id=int(slave_text)))

    if not targets:
        raise ValueError("METER_TARGETS jest puste po sparsowaniu")

    return targets


def _profile(machine_id: int) -> dict:
    """Zwraca profil rejestrow dla konkretnej maszyny.

    Domyslnie oba liczniki czytamy holding registers, bo input registers
    dawaly exception response dla drugiego licznika.
    """
    if machine_id == 181:
        return {
            "meter_type": os.getenv("METER_TYPE_181", "LUMEL_NR32"),
            "reg_fn": os.getenv("METER_REG_FN_181", "holding").strip().lower(),
            "reg_voltage_idx": int(os.getenv("REG_VOLTAGE_IDX_181", str(DEFAULT_VOLTAGE_IDX))),
            "reg_current_idx": int(os.getenv("REG_CURRENT_IDX_181", str(DEFAULT_CURRENT_IDX))),
            "reg_power_idx": int(os.getenv("REG_POWER_IDX_181", str(DEFAULT_POWER_IDX))),
            "reg_energy_total_idx": int(os.getenv("REG_ENERGY_TOTAL_IDX_181", str(DEFAULT_ENERGY_TOTAL_IDX))),
            "power_divider": float(os.getenv("POWER_DIVIDER_181", str(DEFAULT_POWER_DIVIDER))),
        }

    # machine_id=160 i fallback
    return {
        "meter_type": os.getenv("METER_TYPE_160", os.getenv("METER_TYPE", "LUMEL_NMID30_1")),
        "reg_fn": os.getenv("METER_REG_FN_160", DEFAULT_REG_FN).strip().lower(),
        "reg_voltage_idx": int(os.getenv("REG_VOLTAGE_IDX_160", str(DEFAULT_VOLTAGE_IDX))),
        "reg_current_idx": int(os.getenv("REG_CURRENT_IDX_160", str(DEFAULT_CURRENT_IDX))),
        "reg_power_idx": int(os.getenv("REG_POWER_IDX_160", str(DEFAULT_POWER_IDX))),
        "reg_energy_total_idx": int(os.getenv("REG_ENERGY_TOTAL_IDX_160", str(DEFAULT_ENERGY_TOTAL_IDX))),
        "power_divider": float(os.getenv("POWER_DIVIDER_160", str(DEFAULT_POWER_DIVIDER))),
    }


try:
    METER_TARGETS = _parse_meter_targets(METER_TARGETS_RAW)
except ValueError as exc:
    logger.warning("Nieprawidłowe METER_TARGETS (%s) — wracam do pojedynczego licznika.", exc)
    METER_TARGETS = [MeterTarget(machine_id=MASZYNA_ID, slave_id=METER_SLAVE_ID)]


class EnergyMeterReader:
    """Czytnik mierników energii przez Modbus."""

    def __init__(self):
        self.client = None
        self.connection_attempts = 0
        self.last_error = None
        if MODBUS_AVAILABLE:
            self.connect()

    def connect(self):
        """Połączenie z magistralą Modbus."""
        try:
            if MODBUS_MODE == "rtu":
                self.client = ModbusSerialClient(
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
                    logger.info(f"✓ Połączenie z magistralą RS485 {SERIAL_PORT}")
                else:
                    logger.info(f"✓ Połączenie z bramką Modbus TCP {METER_IP}:{METER_PORT}")
                self.connection_attempts = 0
                return True

            raise Exception("Nie można nawiązać połączenia")
        except Exception as e:
            self.connection_attempts += 1
            self.last_error = str(e)
            if self.connection_attempts >= 3:
                if MODBUS_MODE == "rtu":
                    logger.error(
                        f"✗ Brak połączenia z magistralą RS485 ({SERIAL_PORT}) próba {self.connection_attempts}: {e}"
                    )
                else:
                    logger.error(f"✗ Brak połączenia z bramką Modbus TCP (próba {self.connection_attempts}): {e}")
            return False

    def read_registers(self, start_addr, count, slave_id, reg_fn="holding"):
        """Odczyt rejestrów Modbus."""
        if not self.client or not MODBUS_AVAILABLE:
            return None

        try:
            kwargs = {
                "address": start_addr,
                "count": count,
                "unit": slave_id,
            }
            if MODBUS_API == "3.x":
                kwargs = {
                    "address": start_addr,
                    "count": count,
                    "slave": slave_id,
                }

            if reg_fn == "input":
                result = self.client.read_input_registers(**kwargs)
            else:
                result = self.client.read_holding_registers(**kwargs)

            if result is not None and not result.isError():
                return result.registers

            if result is not None and result.isError():
                logger.error(f"Exception response from slave={slave_id}, fn={reg_fn}: {result}")

        except ConnectionException:
            logger.warning("⚠ Utrata połączenia z miernikiem")
            self.connect()
        except Exception as e:
            logger.error(f"Błąd odczytu: {e}")

        return None

    def regs_to_float(self, regs, start_idx):
        """Konwersja 2x16-bit (big endian) → float32."""
        if not regs or len(regs) <= start_idx + 1:
            return 0.0

        high = regs[start_idx]
        low = regs[start_idx + 1]

        import struct

        val = (high << 16) | low
        return struct.unpack(">f", struct.pack(">I", val))[0]

    def read_energy_data(self, machine_id, slave_id):
        """Odczyt danych energii wg profilu maszyny."""
        if DEMO_MODE:
            logger.info("[DEMO_MODE] Wysylam dane testowe")
            return self._dummy_data()

        if not MODBUS_AVAILABLE:
            logger.warning("⚠ Modbus niedostępny - zwracam dane testowe")
            return self._dummy_data()

        profile = _profile(machine_id)
        regs = self.read_registers(
            start_addr=0,
            count=100,
            slave_id=slave_id,
            reg_fn=profile["reg_fn"],
        )
        if not regs:
            return None

        try:
            reg_voltage_idx = profile["reg_voltage_idx"]
            reg_current_idx = profile["reg_current_idx"]
            reg_power_idx = profile["reg_power_idx"]
            reg_energy_total_idx = profile["reg_energy_total_idx"]
            power_divider = float(profile.get("power_divider", 1000.0))

            voltage_v = self.regs_to_float(regs, reg_voltage_idx)
            current_a = self.regs_to_float(regs, reg_current_idx)
            power_kw = self.regs_to_float(regs, reg_power_idx) / power_divider
            energy_kwh_total = self.regs_to_float(regs, reg_energy_total_idx)

            return {
                "voltageV": round(voltage_v, 1),
                "currentA": round(current_a, 2),
                "powerKw": round(power_kw, 2),
                "energyKwhTotal": round(energy_kwh_total, 1),
            }
        except Exception as e:
            logger.error(f"✗ Błąd konwersji danych machineId={machine_id}, slave={slave_id}: {e}")
            return None

    def _dummy_data(self):
        """Dane testowe (dla demo bez miernika)."""
        import random

        return {
            "voltageV": round(230 + random.uniform(-5, 5), 1),
            "currentA": round(10 + random.uniform(-2, 2), 2),
            "powerKw": round(2.5 + random.uniform(-0.5, 0.5), 2),
            "energyKwhTotal": round(1000 + random.uniform(0, 5), 1),
        }

    def send_to_api(self, data, machine_id, slave_id):
        """Wysłanie danych do Drimain API."""
        payload = {
            "maszynaId": machine_id,
            "deviceId": self._device_id(machine_id, slave_id),
            "recordedAt": datetime.utcnow().isoformat() + "Z",
            "voltageV": data.get("voltageV"),
            "currentA": data.get("currentA"),
            "powerKw": data.get("powerKw"),
            "energyKwhTotal": data.get("energyKwhTotal"),
        }

        try:
            headers = {
                "X-API-KEY": DRIMAIN_API_KEY,
                "Content-Type": "application/json",
            }
            response = requests.post(
                DRIMAIN_API_URL,
                json=payload,
                headers=headers,
                timeout=5,
            )

            if response.status_code == 201:
                logger.info(
                    f"✓ API OK | machineId={machine_id} slave={slave_id} | P={data['powerKw']:.1f}kW | E={data['energyKwhTotal']:.1f}kWh | U={data['voltageV']:.0f}V | I={data['currentA']:.1f}A"
                )
                return True

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
        """Główna pętla."""
        logger.info("=" * 60)
        logger.info("🚀 Drimain Energy Reader")
        logger.info(f"   API: {DRIMAIN_API_URL}")
        logger.info(f"   Modbus API: {MODBUS_API}")
        logger.info(f"   Modbus mode: {MODBUS_MODE}")
        logger.info(f"   Demo mode: {'ON' if DEMO_MODE else 'OFF'}")
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
                for target in METER_TARGETS:
                    profile = _profile(target.machine_id)
                    logger.debug(
                        "Reading machineId=%s slave=%s type=%s fn=%s",
                        target.machine_id,
                        target.slave_id,
                        profile["meter_type"],
                        profile["reg_fn"],
                    )

                    data = self.read_energy_data(target.machine_id, target.slave_id)
                    if data:
                        if self.send_to_api(data, target.machine_id, target.slave_id):
                            success_count += 1
                            error_count = 0
                        else:
                            error_count += 1
                    else:
                        error_count += 1
                        logger.warning(
                            f"⚠ Nie udało się odczytać miernika machineId={target.machine_id} slave={target.slave_id} (błędy: {error_count})"
                        )

                time.sleep(READ_INTERVAL)

            except KeyboardInterrupt:
                logger.info("\n⏹ Zatrzymanie (Ctrl+C)")
                logger.info(f"   Pomyślnych: {success_count}")
                break
            except Exception as e:
                logger.error(f"✗ Nieoczekiwany błąd: {e}")
                error_count += 1
                time.sleep(5)

    def _device_id(self, machine_id, slave_id):
        if MODBUS_MODE == "rtu":
            return f"rpi-rs485-{SERIAL_PORT.split('/')[-1]}-m{machine_id}-s{slave_id}"
        return f"rpi-{METER_IP}-m{machine_id}-s{slave_id}"


if __name__ == "__main__":
    reader = EnergyMeterReader()
    reader.run()
