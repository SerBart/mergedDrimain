#!/usr/bin/env python3
"""Map finder for Modbus float32 registers (RTU/TCP).

Purpose:
- find likely register indexes for voltage/current/power/energy,
- compare holding vs input,
- avoid manual guessing.

Example:
  python3 /home/bseredyn/Desktop/scripts/lumel_mapper.py --port /dev/ttyUSB0 --slave 1
"""

from __future__ import annotations

import argparse
import struct
import time
from typing import Dict, List, Tuple

try:
    from pymodbus.client import ModbusSerialClient, ModbusTcpClient
except ImportError:
    from pymodbus.client.sync import ModbusSerialClient, ModbusTcpClient  # type: ignore


def f32_be(regs: List[int]) -> float:
    value = (regs[0] << 16) | regs[1]
    return struct.unpack(">f", struct.pack(">I", value))[0]


def f32_le_wordswap(regs: List[int]) -> float:
    value = (regs[1] << 16) | regs[0]
    return struct.unpack(">f", struct.pack(">I", value))[0]


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


def read_regs(client, fn: str, addr: int, count: int, slave: int, is_v3: bool):
    kwargs = {"address": addr, "count": count}
    kwargs["slave" if is_v3 else "unit"] = slave
    if fn == "holding":
        return client.read_holding_registers(**kwargs)
    return client.read_input_registers(**kwargs)


def rank_candidates(values: Dict[int, float], low: float, high: float, target: float | None = None) -> List[Tuple[int, float, float]]:
    out: List[Tuple[int, float, float]] = []
    for addr, val in values.items():
        if low <= val <= high:
            score = abs(val - target) if target is not None else 0.0
            out.append((addr, val, score))
    out.sort(key=lambda x: x[2])
    return out


def print_top(title: str, data: List[Tuple[int, float, float]], limit: int = 8):
    print(f"\n{title}")
    if not data:
        print("  brak kandydatow")
        return
    for addr, val, score in data[:limit]:
        print(f"  addr={addr:>3}  val={val:>12.3f}  score={score:>10.3f}")


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
    parser.add_argument("--samples", type=int, default=2)
    parser.add_argument("--sample-delay", type=float, default=1.5)
    args = parser.parse_args()

    client = build_client(args)
    if not client.connect():
        print("connect: FAIL")
        return 2

    is_v3 = True
    try:
        from pymodbus import __version__  # type: ignore

        is_v3 = str(__version__).startswith("3")
    except Exception:
        is_v3 = True

    funcs = ["holding", "input"]
    addresses = list(range(args.start, args.end + 1, args.step))

    for fn in funcs:
        print(f"\n=== {fn.upper()} / slave={args.slave} ===")

        # collect samples per address to evaluate stability and growth (energy)
        samples_be: Dict[int, List[float]] = {a: [] for a in addresses}
        samples_le: Dict[int, List[float]] = {a: [] for a in addresses}

        for s in range(args.samples):
            if s > 0:
                time.sleep(args.sample_delay)
            for addr in addresses:
                rr = read_regs(client, fn, addr, 2, args.slave, is_v3)
                if rr is None or rr.isError():
                    continue
                regs = rr.registers
                if len(regs) < 2:
                    continue
                samples_be[addr].append(f32_be(regs))
                samples_le[addr].append(f32_le_wordswap(regs))

        # average values from samples
        avg_be: Dict[int, float] = {a: sum(v) / len(v) for a, v in samples_be.items() if v}
        avg_le: Dict[int, float] = {a: sum(v) / len(v) for a, v in samples_le.items() if v}

        # heuristics for industrial power meter
        u_be = rank_candidates(avg_be, 150.0, 300.0, target=230.0)
        i_be = rank_candidates(avg_be, 0.0, 500.0, target=20.0)
        p_be_kw = rank_candidates({a: v / 1000.0 for a, v in avg_be.items()}, 0.0, 500.0, target=10.0)
        e_be = rank_candidates(avg_be, 0.0, 10_000_000.0, target=None)

        u_le = rank_candidates(avg_le, 150.0, 300.0, target=230.0)
        i_le = rank_candidates(avg_le, 0.0, 500.0, target=20.0)
        p_le_kw = rank_candidates({a: v / 1000.0 for a, v in avg_le.items()}, 0.0, 500.0, target=10.0)
        e_le = rank_candidates(avg_le, 0.0, 10_000_000.0, target=None)

        print_top("BE kandydaci U [V]", u_be)
        print_top("BE kandydaci I [A]", i_be)
        print_top("BE kandydaci P [kW] (raw/1000)", p_be_kw)
        print_top("BE kandydaci E [kWh]", e_be)

        print_top("LE-wordswap kandydaci U [V]", u_le)
        print_top("LE-wordswap kandydaci I [A]", i_le)
        print_top("LE-wordswap kandydaci P [kW] (raw/1000)", p_le_kw)
        print_top("LE-wordswap kandydaci E [kWh]", e_le)

        print("\nSugestia: wybierz jeden wariant (BE albo LE-wordswap),")
        print("gdzie U~230, I wyglada realnie, P jest realne, E sensowne i stale/rosnace.")

    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

