# RPi autostart for Energy Reader

This guide starts `scripts/energy_reader.py` automatically after Raspberry Pi boot using `systemd`.

## Quick checklist

- [ ] Project copied to RPi (example path: `/home/pi/mergedDrimain`)
- [ ] Python venv created in `/home/pi/mergedDrimain/.venv`
- [ ] Dependencies installed (`requests`, `pymodbus`)
- [ ] Env file created in `/etc/drimain-energy-reader.env`
- [ ] Service enabled and started
- [ ] Logs checked with `journalctl`

## 1) Install dependencies on RPi

```bash
cd /home/bseredyn/mergedDrimain
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r scripts/energy_sender_requirements.txt
```

## 2) Create env file for service

```bash
sudo cp /home/bseredyn/Desktop/scripts/systemd/drimain-energy-reader.env.example /etc/drimain-energy-reader.env
sudo nano /etc/drimain-energy-reader.env
```

Minimum required values in `/etc/drimain-energy-reader.env`:
- `DRIMAIN_API_URL`
- `ENERGY_INGEST_KEY`
- `MASZYNA_ID`

If meter is not connected yet:
- keep `DEMO_MODE=false` if you do not want fake readings
- set `DEMO_MODE=true` only for UI demo data

## 3) Install systemd service

```bash
sudo cp /home/bseredyn/Desktop/scripts/systemd/drimain-energy-reader.service /etc/systemd/system/drimain-energy-reader.service
sudo systemctl daemon-reload
sudo systemctl enable drimain-energy-reader.service
sudo systemctl start drimain-energy-reader.service
```

## 4) Verify status and logs

```bash
sudo systemctl status drimain-energy-reader.service --no-pager
sudo journalctl -u drimain-energy-reader.service -f
```

Expected behavior:
- if meter is disconnected and `DEMO_MODE=false`, you will see warning about read errors
- if API key is wrong, backend returns `403`
- if all is correct, logs show `API OK`

## 5) Useful operations

```bash
sudo systemctl restart drimain-energy-reader.service
sudo systemctl stop drimain-energy-reader.service
sudo systemctl disable drimain-energy-reader.service
```

## Notes

- Service file assumes user `bseredyn` and project path `/home/bseredyn/Desktop`.
- If your RPi path differs, update `User`, `Group`, `WorkingDirectory`, and `ExecStart` in `scripts/systemd/drimain-energy-reader.service` before copying it.

