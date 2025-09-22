# Production deployment

## Environment variables
- SPRING_DATASOURCE_URL
- SPRING_DATASOURCE_USERNAME
- SPRING_DATASOURCE_PASSWORD
- JWT_SECRET
- JWT_ACCESS_TTL_MS (default: 900000 = 15 min)
- JWT_REFRESH_TTL_MS (default: 604800000 = 7 days)
- CORS_ALLOWED_ORIGINS (comma-separated, e.g. https://app.example.com)

## Local production-like run (Docker Compose)
```bash
docker compose -f docker-compose.prod.yml up -d --build
curl -fsSL http://localhost:8080/actuator/health || true
```

## CI
- Każdy push/PR do `main`: build+test backendu (Maven). Dodatkowo, jeśli istnieją katalogi `frontend/` i/lub `client/`, uruchamiane są odpowiednio: analiza/testy Flutter, build klienta TS.

## Release
- Tag `vX.Y.Z` → budowa i publikacja obrazu do GHCR: `ghcr.io/<owner>/<repo>:vX.Y.Z` oraz `:latest`.

## Notes
- Swagger/OpenAPI UI wyłączony w prod.
- CORS sterowany ENV – domyślnie brak zewnętrznych originów.
- W prod `ddl-auto=validate`, używaj migracji (Flyway).