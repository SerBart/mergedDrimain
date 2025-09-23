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