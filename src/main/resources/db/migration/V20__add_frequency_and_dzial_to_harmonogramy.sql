-- V20: dodanie kolumn frequency oraz dzial_id do tabeli harmonogramy (wersja warunkowa)
-- Zaktualizowane: użycie bloków DO aby uniknąć błędów duplicate column jeśli kolumny już istnieją.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='harmonogramy' AND column_name='frequency'
    ) THEN
        ALTER TABLE harmonogramy ADD COLUMN frequency VARCHAR(20);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='harmonogramy' AND column_name='dzial_id'
    ) THEN
        ALTER TABLE harmonogramy ADD COLUMN dzial_id BIGINT;
    END IF;
END $$;

-- Indeks tylko jeśli brak kolumny (a więc i indeksu) lub jeśli kolumna istnieje ale indeksu brak
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='harmonogramy' AND column_name='dzial_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_class c
         JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE c.relname = 'idx_harmonogramy_dzial_id'
           AND c.relkind = 'i'
    ) THEN
        EXECUTE 'CREATE INDEX idx_harmonogramy_dzial_id ON harmonogramy(dzial_id)';
    END IF;
END $$;

-- Klucz obcy jeśli brak
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='harmonogramy' AND column_name='dzial_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name='harmonogramy' AND constraint_name='fk_harmonogramy_dzial'
    ) THEN
        ALTER TABLE harmonogramy
            ADD CONSTRAINT fk_harmonogramy_dzial FOREIGN KEY (dzial_id) REFERENCES dzialy(id);
    END IF;
END $$;

-- Kolumny pozostają opcjonalne (NULL) zgodnie z encją Harmonogram.
