-- dataGodzina -> data_godzina
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='zgloszenia' AND column_name='datagodzina') THEN
    EXECUTE 'ALTER TABLE zgloszenia RENAME COLUMN datagodzina TO data_godzina';
  END IF;
END $$;

-- Dodanie brakujących kolumn z encji Zgloszenie
ALTER TABLE zgloszenia
  ADD COLUMN IF NOT EXISTS tytul        VARCHAR(200),
  ADD COLUMN IF NOT EXISTS priorytet    VARCHAR(40),
  ADD COLUMN IF NOT EXISTS created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at   TIMESTAMP NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS dzial_id     BIGINT,
  ADD COLUMN IF NOT EXISTS autor_id     BIGINT;

-- Indeksy/FK (opcjonalnie, jeśli chcesz relacje; zostaw jeśli mogą być null)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name='zgloszenia' AND constraint_name='fk_zgloszenia_dzial'
  ) THEN
    EXECUTE 'ALTER TABLE zgloszenia ADD CONSTRAINT fk_zgloszenia_dzial FOREIGN KEY (dzial_id) REFERENCES dzialy(id)';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name='zgloszenia' AND constraint_name='fk_zgloszenia_autor'
  ) THEN
    EXECUTE 'ALTER TABLE zgloszenia ADD CONSTRAINT fk_zgloszenia_autor FOREIGN KEY (autor_id) REFERENCES users(id)';
  END IF;
END $$;