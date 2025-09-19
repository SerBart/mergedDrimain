-- Dodanie brakujących kolumn wymaganych przez encję Osoba
ALTER TABLE osoby
  ADD COLUMN IF NOT EXISTS login          VARCHAR(255),
  ADD COLUMN IF NOT EXISTS haslo          VARCHAR(255),
  ADD COLUMN IF NOT EXISTS imie_nazwisko  VARCHAR(255),
  ADD COLUMN IF NOT EXISTS rola           VARCHAR(255);

-- (Opcjonalnie) Uzupełnij imie_nazwisko z istniejących kolumn imie/nazwisko, jeśli takie masz z V1
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osoby' AND column_name='imie')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osoby' AND column_name='nazwisko') THEN
    EXECUTE $sql$
      UPDATE osoby
      SET imie_nazwisko = TRIM(
        COALESCE(imie, '') ||
        CASE WHEN imie IS NOT NULL AND nazwisko IS NOT NULL THEN ' ' ELSE '' END ||
        COALESCE(nazwisko, '')
      )
      WHERE imie_nazwisko IS NULL
    $sql$;
  END IF;
END $$;

-- (Opcjonalnie) Jeżeli chcesz unikalności loginu:
-- CREATE UNIQUE INDEX IF NOT EXISTS ux_osoby_login ON osoby(login);