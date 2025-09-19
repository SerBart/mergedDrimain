-- Dodaje kolumnę dzial_id oraz klucz obcy do dzialy(id) i indeks

ALTER TABLE maszyny
  ADD COLUMN IF NOT EXISTS dzial_id BIGINT;

CREATE INDEX IF NOT EXISTS idx_maszyny_dzial_id ON maszyny(dzial_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints tc
    WHERE tc.table_name = 'maszyny'
      AND tc.constraint_type = 'FOREIGN KEY'
      AND tc.constraint_name = 'fk_maszyny_dzial'
  ) THEN
    EXECUTE 'ALTER TABLE maszyny
             ADD CONSTRAINT fk_maszyny_dzial
             FOREIGN KEY (dzial_id) REFERENCES dzialy(id)';
  END IF;
END $$;

-- Opcjonalnie: jeśli pojawi się błąd o nullable kolumnie "nazwa" (encja ma @Column(nullable=false)):
-- ALTER TABLE maszyny ALTER COLUMN nazwa SET NOT NULL;