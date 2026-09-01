#!/usr/bin/env python3
"""Tiny Raspberry Pi sender for energy readings.

Usage:
  set API_BASE_URL, ENERGY_INGEST_KEY, MACHINE_ID, DEVICE_ID
  optionally set POWER_KW, ENERGY_KWH_TOTAL, VOLTAGE_V, CURRENT_A, RECORDED_AT

Example:
  python energy_sender.py
"""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone

import requests


def env(name: str, default: str = "") -> str:
    value = os.getenv(name, default)
    if value is None:
        return default
    return value.strip()


def main() -> int:
    base_url = env("API_BASE_URL", "http://localhost:8080").rstrip("/")
    ingest_key = env("ENERGY_INGEST_KEY")
    machine_id = env("MACHINE_ID")
    device_id = env("DEVICE_ID", "raspi-01")

    if not ingest_key:
        raise SystemExit("Missing ENERGY_INGEST_KEY")
    if not machine_id:
        raise SystemExit("Missing MACHINE_ID")

    recorded_at = env("RECORDED_AT", datetime.now(timezone.utc).isoformat())
    payload = {
        "maszynaId": int(machine_id),
        "deviceId": device_id,
        "recordedAt": recorded_at,
        "powerKw": float(env("POWER_KW", "0")),
        "energyKwhTotal": float(env("ENERGY_KWH_TOTAL", "0")),
    }

    voltage_v = env("VOLTAGE_V")
    current_a = env("CURRENT_A")
    if voltage_v:
        payload["voltageV"] = float(voltage_v)
    if current_a:
        payload["currentA"] = float(current_a)

    url = f"{base_url}/api/energia/readings"
    response = requests.post(
        url,
        headers={"X-API-KEY": ingest_key, "Content-Type": "application/json"},
        data=json.dumps(payload),
        timeout=15,
    )
    response.raise_for_status()
    print(response.json())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

