#!/usr/bin/env python3
"""
DIAGNOSTIC TOOL - Dump ALL registers from Modbus meter
"""

import os
import sys

MODBUS_MODE = os.getenv("MODBUS_MODE", "rtu").strip().lower()
METER_IP = os.getenv("METER_IP", "192.168.1.50")
METER_PORT = int(os.getenv("METER_PORT", "502"))
SERIAL_PORT = os.getenv("SERIAL_PORT", "/dev/ttyUSB0")
BAUD_RATE = int(os.getenv("BAUD_RATE", "9600"))

print(f"⚙️  Config: MODE={MODBUS_MODE}, IP={METER_IP}, PORT={METER_PORT}, SERIAL={SERIAL_PORT}, BAUD={BAUD_RATE}")

try:
    from pymodbus.client.sync import ModbusSerialClient, ModbusTcpClient
    MODBUS_API = "2.x"
    print("✓ Modbus 2.x imported")
except ImportError:
    try:
        from pymodbus.client import ModbusSerialClient, ModbusTcpClient
        MODBUS_API = "3.x"
        print("✓ Modbus 3.x imported")
    except ImportError:
        print("✗ Modbus not installed!")
        sys.exit(1)

# Connect
if MODBUS_MODE == "rtu":
    client = ModbusSerialClient(
        port=SERIAL_PORT,
        baudrate=BAUD_RATE,
        parity="N",
        stopbits=1,
        bytesize=8,
        timeout=3,
    )
else:
    client = ModbusTcpClient(host=METER_IP, port=METER_PORT, timeout=3)

if not client.connect():
    print("✗ Cannot connect!")
    sys.exit(1)

print("✓ Connected!\n")

# Test both slaves
for slave_id in [1, 2]:
    print(f"\n{'='*70}")
    print(f"SLAVE {slave_id} - Reading holding registers 0-99")
    print(f"{'='*70}\n")

    try:
        # Modbus API differences
        if MODBUS_API == "3.x":
            result = client.read_holding_registers(address=0, count=100, slave=slave_id)
        else:
            result = client.read_holding_registers(address=0, count=100, unit=slave_id)

        if result is None or result.isError():
            print(f"⚠️  Error reading slave {slave_id}: {result}")
            continue

        regs = result.registers
        print(f"✓ Got {len(regs)} registers\n")

        # Print in 10-column format
        for i in range(0, len(regs), 10):
            idx_start = i
            idx_end = min(i+10, len(regs))

            # Print index row
            print(f"[{idx_start:3d}-{idx_end-1:3d}] ", end="")
            for j in range(idx_start, idx_end):
                print(f"{regs[j]:5d}  ", end="")
            print()

        # Print as 32-bit floats (2 registers = 1 float)
        print(f"\n--- Interpretation as 32-bit floats (big-endian) ---")
        import struct
        for i in range(0, len(regs)-1, 2):
            high = regs[i]
            low = regs[i+1]
            val = (high << 16) | low
            f_val = struct.unpack(">f", struct.pack(">I", val))[0]
            print(f"[{i:3d}-{i+1}] {high:5d} {low:5d} => {f_val:12.4f}")

    except Exception as e:
        print(f"✗ Exception on slave {slave_id}: {e}")

client.close()
print("\n✓ Done!")

