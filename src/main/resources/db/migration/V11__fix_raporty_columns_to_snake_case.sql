DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='raporty' AND column_name='typnaprawy') THEN
    EXECUTE 'ALTER TABLE raporty RENAME COLUMN typnaprawy TO typ_naprawy';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='raporty' AND column_name='datanaprawy') THEN
    EXECUTE 'ALTER TABLE raporty RENAME COLUMN datanaprawy TO data_naprawy';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='raporty' AND column_name='czasod') THEN
    EXECUTE 'ALTER TABLE raporty RENAME COLUMN czasod TO czas_od';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='raporty' AND column_name='czasdo') THEN
    EXECUTE 'ALTER TABLE raporty RENAME COLUMN czasdo TO czas_do';
  END IF;
END $$;