-- V18: Dodanie brakujących kolumn do tabeli zgloszenia zgodnie z encją Zgloszenie
-- Kolumny: accepted_at, completed_at, maszyna_id (FK), oraz naprawcze ustawienie priorytetu

-- Dodanie kolumn jeśli nie istnieją
ALTER TABLE zgloszenia
    ADD COLUMN IF NOT EXISTS accepted_at   TIMESTAMP,
    ADD COLUMN IF NOT EXISTS completed_at  TIMESTAMP,
    ADD COLUMN IF NOT EXISTS maszyna_id    BIGINT;

-- Dodanie klucza obcego do maszyny jeśli nie istnieje
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name='zgloszenia' AND constraint_name='fk_zgloszenia_maszyna'
    ) THEN
        EXECUTE 'ALTER TABLE zgloszenia ADD CONSTRAINT fk_zgloszenia_maszyna FOREIGN KEY (maszyna_id) REFERENCES maszyny(id)';
    END IF;
END $$;

-- Uzupełnienie domyślnego priorytetu jeśli brak (encja ustawia domyślnie NORMALNY)
UPDATE zgloszenia SET priorytet = 'NORMALNY' WHERE priorytet IS NULL;

-- (Opcjonalnie) Można wymusić NOT NULL, ale tylko jeśli mamy pewność że wszystkie rekordy są zapełnione
-- ALTER TABLE zgloszenia ALTER COLUMN priorytet SET NOT NULL;

