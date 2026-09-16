# Chat i Ogloszenia - Etap 1

## Zakres
- Wiadomosci 1:1 miedzy uzytkownikami
- Ogloszenia globalne (tworzenie przez admina)
- Powiadomienia o nowej wiadomosci i nowym ogloszeniu

## Backend API

### Wiadomosci
- `GET /api/messages/contacts` - lista kontaktow do rozmow + licznik nieprzeczytanych
- `GET /api/messages/thread/{userId}?limit=100` - historia wiadomosci 1:1
- `POST /api/messages` - wysylka wiadomosci
  - body:
    ```json
    {
      "recipientUserId": 2,
      "content": "Czesc, sprawdz prosze zgloszenie #123"
    }
    ```
- `POST /api/messages/thread/{userId}/read` - oznaczenie rozmowy jako przeczytanej

### Ogloszenia
- `GET /api/announcements` - lista aktywnych ogloszen
- `POST /api/announcements` - dodanie ogloszenia (tylko ADMIN)
  - body:
    ```json
    {
      "title": "Przerwa serwisowa",
      "content": "W sobote 10:00-12:00 planowana przerwa serwisowa"
    }
    ```

## UI
- Trasa: `/messages` (ekran Wiadomosci)
- Trasa: `/announcements` (ekran Ogloszenia)
- Kafelki na dashboardzie:
  - Wiadomosci
  - Ogloszenia

## Migracje
- `V36__create_messages_and_announcements.sql`

## Uwagi
- Etap 1 nie zawiera czatu grupowego.
- Etap 1 nie zawiera websocket push dla czatu (dziala polling/odswiezanie).
- Powiadomienia o nowych wiadomosciach i ogloszeniach sa zapisywane w tabeli `notifications`.

