-- Dodaje kolumnę dzial_id oraz klucz obcy do dzialy(id) i indeks

ALTER TABLE maszyny
  ADD COLUMN IF NOT EXISTS dzial_id BIGINT;

CREATE INDEX IF NOT EXISTS idx_maszyny_dzial_id ON maszyny(dzial_id);

-- H2/PostgreSQL compatible: dodaj FK jeśli nie istnieje
ALTER TABLE maszyny
  ADD CONSTRAINT IF NOT EXISTS fk_maszyny_dzial
  FOREIGN KEY (dzial_id) REFERENCES dzialy(id);

-- Opcjonalnie: jeśli pojawi się błąd o nullable kolumnie "nazwa" (encja ma @Column(nullable=false)):
-- ALTER TABLE maszyny ALTER COLUMN nazwa SET NOT NULL;