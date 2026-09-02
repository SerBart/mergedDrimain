# Energy module integration

## API flow
- Raspberry Pi sends `POST /api/energia/readings`
- Backend validates `X-API-KEY`
- Backend updates live state for SSE and stores snapshots in PostgreSQL on Railway
- Flutter dashboard shows the `Zużycie energii` tile and `/energia` screen

## Required environment variables
- `ENERGY_INGEST_KEY` - secret shared by Raspberry Pi and backend
- `DATABASE_URL` or Railway `PG*` variables

## Suggested payload from Raspberry Pi
```json
{
  "maszynaId": 12,
  "deviceId": "raspi-press-01",
  "recordedAt": "2026-08-28T10:15:00Z",
  "powerKw": 4.82,
  "energyKwhTotal": 1284.56,
  "voltageV": 398.2,
  "currentA": 7.1
}
```

## Sampling
- send readings every 5 seconds for live view
- backend stores the latest snapshot every 5 minutes for history
- `/api/energia/machines/{id}/history` returns points for charting

