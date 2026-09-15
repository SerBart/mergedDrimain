# Import czesci z Excel

## Obslugiwany schemat naglowka
Plik `.xlsx` musi miec pierwszy wiersz z kolumnami (kolejnosc dowolna):

- `PRIORYTET`
- `NAZWA`
- `OPIS`
- `ILOSC` (akceptowane takze `ILOŚĆ`)
- `JEDNOSTKA` (akceptowane takze historyczne `JEDNOSTA`)
- `DATA ZGLOSZENIA`
- `DATA REALIZACJI`
- `STATUS`
- `OSOBA`
- `DZIAL`

Polskie znaki i spacje sa normalizowane, wiec naglowki jak `DATA ZGŁOSZENIA` i `DZIAŁ` tez sa akceptowane.

## Mapowanie kolumn do modelu Part
- `NAZWA` -> `Part.nazwa`
- `OPIS` -> `Part.opis`
- `ILOSC` -> `Part.ilosc`
- `JEDNOSTKA` -> `Part.jednostka`
- `DZIAL` -> `Part.kategoria`
- `maszyna` jest ustawiana na `null` podczas importu

## Upsert (bez duplikatow)
Import szuka rekordu po kluczu naturalnym:
`(nazwa, opis, kategoria)` z porownaniem case-insensitive.

- jesli rekord istnieje -> aktualizacja (`updatedCount`)
- jesli nie istnieje -> utworzenie (`createdCount`)

## Endpoint
`POST /api/czesci/import` (multipart form-data)

Pole formularza: `file`

## Odpowiedz API
JSON zawiera:
- `importedCount`
- `createdCount`
- `updatedCount`
- `skippedCount`
- `warnings[]`

