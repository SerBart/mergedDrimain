# TODO: Railway + Raspberry Pi (Energy ingest + SSE)

Ten plik to praktyczna checklista od zera do dzialajacego wysylania danych energii z RPi do backendu na Railway.

## 0) Co juz masz

- `APP_JWT_SECRET` na Railway: ustawione (ok).

## 1) Railway - backend service

### 1.1 Wymagane zmienne

- [ ] `APP_JWT_SECRET` (masz juz ustawione)
- [ ] `ENERGY_INGEST_KEY` (wspolny sekret backend <-> RPi, np. 32+ znakow)

### 1.2 Zalecane zmienne

- [ ] `ADMIN_PASSWORD` (wlasne haslo admina)
- [ ] `APP_CORS_ALLOWED_ORIGINS` (jesli frontend jest na innej domenie)
- [ ] `FLYWAY_ENABLED=true` (dla PostgreSQL na Railway)

### 1.3 Opcjonalne pod SSE

- [ ] `SSE_HEARTBEAT_SECONDS=30`
- [ ] `SSE_CLIENT_TIMEOUT_SECONDS=300`
- [ ] `SSE_MAX_CLIENTS=100`

### 1.4 Baza danych

- [ ] Podlacz PostgreSQL service w Railway
- [ ] Nie ustawiaj recznie `PORT` (Railway daje automatycznie)
- [ ] Nie ustawiaj recznie `DATABASE_URL`/`PG*`, jesli Railway juz je wstrzykuje

## 2) Co i gdzie zmienic w repo

### 2.1 Skrypt na RPi

Plik: `scripts/energy_reader.py`

Zmien sekcje konfiguracji:

- [ ] `DRIMAIN_API_URL` na produkcyjny URL Railway, np. `https://twoj-backend.up.railway.app/api/energia/readings`
- [ ] `DRIMAIN_API_KEY` na wartosc `ENERGY_INGEST_KEY` z Railway
- [ ] `MASZYNA_ID` na istniejące ID maszyny w Twojej bazie
- [ ] `METER_TYPE`, `METER_IP`, `METER_PORT`, `METER_SLAVE_ID` pod realny licznik
- [ ] `READ_INTERVAL` (sekundy)

## 3) Przygotowanie Raspberry Pi

Pelna instrukcja autostartu uslugi po restarcie RPi:
- `docs/RPI_AUTOSTART.md`

### 3.1 Instalacja zaleznosci

Uwaga: `scripts/energy_sender_requirements.txt` zawiera tylko `requests`; do Modbus potrzebujesz tez `pymodbus`.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r scripts/energy_sender_requirements.txt
pip install pymodbus
```

### 3.2 Uruchomienie testowe

```bash
python3 scripts/energy_reader.py
```

Szukaj w logu:
- `API OK` -> ingest dziala
- `403` -> zly `X-API-KEY` (niezgodny z `ENERGY_INGEST_KEY`)
- timeout/connection -> problem sieciowy lub zly URL

## 4) Testy endpointu bez RPi (szybka diagnostyka)

Podstaw `URL` i `KEY`:

```bash
curl -i -X POST "https://TWOJ_BACKEND.up.railway.app/api/energia/readings" \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: TWOJ_ENERGY_INGEST_KEY" \
  -d '{
    "maszynaId": 1,
    "deviceId": "rpi-test",
    "recordedAt": "2026-09-01T12:00:00Z",
    "powerKw": 2.5,
    "energyKwhTotal": 1234.5,
    "voltageV": 230.0,
    "currentA": 10.0
  }'
```

Oczekiwane:
- `201 Created` -> OK
- `403 Forbidden` -> zly lub pusty klucz
- `400` -> payload niezgodny z DTO

## 5) Front/SSE - co musisz sprawdzic

- [ ] SSE listener uruchamiasz w `initState`, zamykasz w `dispose` (to planujesz i to jest poprawne)
- [ ] Klient SSE ma reconnect po rozlaczeniu (normalne na hostingu)
- [ ] Jesli frontend i backend sa na roznych domenach, CORS musi zawierac frontend origin

## 6) Najczestsze bledy

- Brak `ENERGY_INGEST_KEY` na Railway -> zawsze 403 na `/api/energia/readings`
- Inna wartosc klucza w RPi niz w Railway -> 403
- Zly `MASZYNA_ID` -> zapis nie przejdzie lub mapowanie bedzie bledne
- Brak `pymodbus` -> skrypt przechodzi w dane testowe/fallback
- URL z `http` zamiast `https` do Railway -> problemy sieciowe

## 7) Minimalny plan "zrob to teraz"

- [ ] Railway: ustaw `ENERGY_INGEST_KEY`
- [ ] RPi: wpisz ten sam klucz do `DRIMAIN_API_KEY`
- [ ] RPi: ustaw poprawny `DRIMAIN_API_URL` (Railway)
- [ ] RPi: zainstaluj `pymodbus`
- [ ] Uruchom `python3 scripts/energy_reader.py` i potwierdz `API OK`

## 8) Zrodla w kodzie (dla pewnosci)

- Walidacja klucza naglowka `X-API-KEY`: `src/main/java/drimer/drimain/controller/EnergyController.java`
- Mapowanie klucza z env: `src/main/resources/application.yml` (`app.energy.ingest-key: ${ENERGY_INGEST_KEY:}`)
- Produkcyjne mapowanie: `src/main/resources/application-prod.yml`
- Integracyjny skrypt RPi: `scripts/energy_reader.py`

