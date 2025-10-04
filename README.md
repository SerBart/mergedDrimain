... (pozostała treść pliku bez zmian)

### Frontend Development

1. Instalacja zależności:
```bash
cd frontend
flutter pub get
```

2. Tryb developerski (CORS włączony dla localhost:*):
```bash
cd frontend
flutter run -d web --dart-define=API_BASE=http://localhost:8080
```

3. Build zintegrowany (same-origin, bez CORS):
```bash
./build-frontend.sh
./mvnw spring-boot:run
# Otwórz http://localhost:8080 – SPA korzysta z /api/** na tym samym host:port
```

Uwaga: API_BASE jest odczytywane z --dart-define. Gdy nie podasz tej wartości (build zintegrowany), frontend domyślnie użyje same-origin „/api”.

## Deploy na Railway

Są dwie wspierane ścieżki uruchomienia na Railway:

1) Dockerfile (zalecane – najprostsze)
- Upewnij się, że źródło deployu w Railway to Dockerfile z repozytorium.
- Nie ustawiaj własnego „Start Command” – użyty zostanie ENTRYPOINT z Dockerfile.
- Aplikacja sama pobierze port z env `PORT` (w `application.yml`: `server.port: ${PORT:8080}`)

2) Buildpacks/Nixpacks (bez Dockera)
- Build Command: `./mvnw -DskipTests package`
- Start Command: `java -Dserver.port=${PORT} -XX:MaxRAMPercentage=75.0 -jar target/driMain-1.0.0.jar`
- Repo zawiera pliki `Procfile` i `nixpacks.toml`, więc Railway powinien wykryć poprawne komendy automatycznie.

Wymagane/zalecane zmienne środowiskowe na Railway:
- `APP_JWT_SECRET` – ustaw silny sekret (min. 32 znaki)
- Opcjonalnie CORS: `CORS_ALLOWED_ORIGINS` lub `APP_CORS_ALLOWED_ORIGINS`
- Opcjonalnie Postgres (jeśli nie chcesz H2): `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` oraz `FLYWAY_ENABLED=true`

Szybki test (po deployu):
- Otwórz `/swagger-ui/index.html`
- Wejście na `/` powinno przekierować do logowania
- `GET /api/parts` bez tokenu powinien zwrócić 401

Uwaga (częsty błąd):
- Nie używaj komendy Mavena z `".run.arguments=..."`. To powoduje błąd: „Unknown lifecycle phase”. Zawsze używaj: `-Dspring-boot.run.arguments=...` lub, prościej, uruchamiaj gotowy JAR jak wyżej.
