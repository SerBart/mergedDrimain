DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'parts' AND column_name = 'minilosc'
  ) THEN
    EXECUTE 'ALTER TABLE parts RENAME COLUMN minilosc TO min_ilosc';
  END IF;
END $$;

-- Na wypadek świeżej bazy lub wcześniejszych zmian:
ALTER TABLE parts
  ADD COLUMN IF NOT EXISTS min_ilosc INTEGER;