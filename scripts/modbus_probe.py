#!/usr/bin/env python3
"""Simple Modbus probe for finding valid register ranges.

Usage examples:
  python3 scripts/modbus_probe.py --port /dev/ttyUSB0 --slave 2
  python3 scripts/modbus_probe.py --port /dev/ttyUSB0 --slave 1 --mode rtu --start 0 --end 120 --step 2

It tries both holding and input registers and prints only successful reads or explicit Modbus errors.
"""

from __future__ import annotations

import argparse
from typing import Iterable, Optional


try:
    from pymodbus.client import ModbusSerialClient, ModbusTcpClient
except ImportError:
    from pymodbus.client.sync import ModbusSerialClient, ModbusTcpClient  # type: ignore


def build_client(args):
    if args.mode == "tcp":
        return ModbusTcpClient(host=args.host, port=args.tcp_port, timeout=args.timeout)
    return ModbusSerialClient(
        port=args.port,
        baudrate=args.baudrate,
        parity=args.parity,
        stopbits=args.stopbits,
        bytesize=args.bytesize,
        timeout=args.timeout,
    )


def read_with_client(client, fn: str, addr: int, count: int, slave: int, pymodbus_version: int):
    kwargs = {"address": addr, "count": count}
    if pymodbus_version == 3:
        kwargs["slave"] = slave
    else:
        kwargs["unit"] = slave

    if fn == "holding":
        return client.read_holding_registers(**kwargs)
    return client.read_input_registers(**kwargs)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["rtu", "tcp"], default="rtu")
    parser.add_argument("--port", default="/dev/ttyUSB0")
    parser.add_argument("--host", default="192.168.1.50")
    parser.add_argument("--tcp-port", type=int, default=502)
    parser.add_argument("--baudrate", type=int, default=9600)
    parser.add_argument("--parity", default="N")
    parser.add_argument("--stopbits", type=int, default=1)
    parser.add_argument("--bytesize", type=int, default=8)
    parser.add_argument("--timeout", type=float, default=2.0)
    parser.add_argument("--slave", type=int, required=True)
    parser.add_argument("--start", type=int, default=0)
    parser.add_argument("--end", type=int, default=120)
    parser.add_argument("--step", type=int, default=2)
    parser.add_argument("--count", type=int, default=2)
    parser.add_argument("--fn", choices=["holding", "input", "both"], default="both")
    args = parser.parse_args()

    client = build_client(args)
    if not client.connect():
        print("connect: FAIL")
        return 2

    pymodbus_version = 3
    try:
        # runtime probe: pymodbus 3 client uses slave=, 2.x uses unit=
        # We don't know exact version here, but in practice this is safe:
        from pymodbus import __version__  # type: ignore
        pymodbus_version = 3 if str(__version__).startswith("3") else 2
    except Exception:
        pymodbus_version = 3

    funcs = ["holding", "input"] if args.fn == "both" else [args.fn]

    print(f"connect: OK | mode={args.mode} | slave={args.slave} | range={args.start}..{args.end} step={args.step} count={args.count}")
    for fn in funcs:
        print(f"\n== {fn.upper()} ==")
        for addr in range(args.start, args.end + 1, args.step):
            try:
                rr = read_with_client(client, fn, addr, args.count, args.slave, pymodbus_version)
                if rr is None:
                    print(f"addr={addr:>3}: no response")
                    continue
                if rr.isError():
                    # Keep errors visible because they tell us about illegal function / address.
                    print(f"addr={addr:>3}: ERR {rr}")
                    continue
                print(f"addr={addr:>3}: OK  {rr.registers}")
            except Exception as e:
                print(f"addr={addr:>3}: EXC {e}")

    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

