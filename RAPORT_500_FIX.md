# Naprawa błędu HTTP 500 przy pobieraniu raportów

## Problem
Aplikacja zwracała `HTTP 500 DioException` przy pobieraniu listy raportów (`GET /api/raporty`). Błąd wynikał z kilku przyczyn:

1. **LazyInitializationException** - pobieranie użytkownika bez fetch join na relację `dzial`, a następnie próba dostępu do `user.getDzial()` poza transakcją
2. **Niewalidowane pola sortowania** - niepoprawne pole sortowania mogło spowodować runtime exception w JPA
3. **Mapowanie DTO** - brak null-safety przy mapowaniu `PartUsage` i innych relacji
4. **Specyfikacje JPA** - brak defensywnych null checków w warunkach filtrowania po dziale

## Wprowadzone zmiany

### 1. RaportRestController (`src/main/java/drimer/drimain/controller/RaportRestController.java`)

#### Walidacja pól sortowania
- Dodana whitelistę pól do sortowania: `id`, `dataNaprawy`, `typNaprawy`, `status`, `createdBy`, `zgloszenieId`
- Pola spoza whitelisty są ignorowane z logowaniem ostrzeżenia
- Zapobiega to runtime exception przy złych polach sortowania

#### Bezpieczne pobranie działu użytkownika
- Zmieniono `findByUsername()` na `findByUsernameFetchDzial()` (fetch join)
- Dodane null-checking dla użytkownika
- Unikła się LazyInitializationException na dostępie do `user.getDzial()`

#### Zmiana statusu dla /api/raporty/{id}
- Zmieniono `IllegalArgumentException` na `ResponseStatusException` z `404`
- Bardziej semantycznie poprawne dla RESTful API

### 2. RaportMapper (`src/main/java/drimer/drimain/api/mapper/RaportMapper.java`)

#### Kompletny null-safety w toDto()
- Wrapper metody z null-checking dla całego obiektu
- Każde pole mapowane w oddzielnym try-catch bloku
- Fallback do `null` lub pustej listy dla każdego pola
- Logowanie ostrzeżeń zamiast rzucania exception

#### Nowa metoda mapPartUsages()
- Ekstrakcja logiki mapowania `PartUsage` do osobnej metody
- Null-checking na `PartUsage` i `Part`
- Filtrowanie null-owych wyników ze streama

### 3. RaportSpecifications (`src/main/java/drimer/drimain/repository/spec/RaportSpecifications.java`)

#### Defensywne null-checking w hasDzial()
```java
cb.and(
    cb.isNotNull(root.get("maszyna")),
    cb.isNotNull(root.get("maszyna").get("dzial")),
    cb.equal(root.get("maszyna").get("dzial").get("id"), dzialId)
)
```

#### Uproszczona logika w excludeDzialByName()
- OR warunkowy: `isNull(maszyna) OR isNull(dzial) OR nazwa != dzialName`
- Unikła się redundantnych null checków w AND

### 4. ZgloszenieRestController (`src/main/java/drimer/drimain/controller/ZgloszenieRestController.java`)

#### Bezpieczne pobranie działu użytkownika
- Zmieniono dwa miejsca `findByUsername()` na `findByUsernameFetchDzial()`
- Linii 79 i 239
- Spójne podejście jak w RaportRestController

### 5. NotificationRestController (`src/main/java/drimer/drimain/controller/NotificationRestController.java`)

#### Konsystentne pobieranie użytkownika
- Zmieniono `findByUsername()` na `findByUsernameFetchDzial()` w test endpoincie (linii 72)
- Spójne z innymi kontrolerami

### 6. ApiExceptionHandler (`src/main/java/drimer/drimain/api/exception/ApiExceptionHandler.java`)

#### Dodane logowanie
- Dodano `@Slf4j` i logowanie pełnego stacktrace'a w catch-all handler
- Ułatwia diagnozy 500 błędów na produkcji

## Testowanie

### Test regresyjny
- Dodany test w `RaportRestControllerIntegrationTest`
- `listRaportow_withUnsupportedSort_returns200()` - testuje że nieznane pole sortowania nie powoduje 500

### Ręczne testowanie
```bash
# Uruchomić aplikację
./mvnw spring-boot:run

# Test listy raportów
curl -H "Authorization: Bearer <token>" http://localhost:8080/api/raporty

# Test z nieprawidłowym sortem
curl -H "Authorization: Bearer <token>" http://localhost:8080/api/raporty?sort=invalidField:asc

# Test singla
curl -H "Authorization: Bearer <token>" http://localhost:8080/api/raporty/1
```

## Potencjalne pozostałe problemy

1. **Inne mappery** - być może inne DTOs mogą mieć podobne problemy, ale ZgloszenieMapper już ma try-catch safety
2. **Transakcje** - Niektóre operacje mogą wymagać `@Transactional(readOnly=true)` aby uniknąć LazyInitializationException
3. **EntityGraph** - Można rozszerzyć EntityGraph na RaportRepository jeśli potrzebne są dodatkowe relacje

## Podsumowanie zmian
- **Kontrolery**: 3 (RaportRestController, ZgloszenieRestController, NotificationRestController)
- **Mappery**: 1 (RaportMapper)
- **Specyfikacje**: 1 (RaportSpecifications)
- **Exception handlers**: 1 (ApiExceptionHandler)
- **Testy**: +1 test regresyjny

Wszystkie zmiany mają na celu zwiększenie odporności na błędy i lepszą diagnostykę problemów w produkcji.

