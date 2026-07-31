CREATE TABLE IF NOT EXISTS sekcje (
    id BIGSERIAL PRIMARY KEY,
    dzial_id BIGINT NOT NULL REFERENCES dzialy(id) ON DELETE CASCADE,
    nazwa VARCHAR(255) NOT NULL,
    CONSTRAINT uk_sekcje_dzial_nazwa UNIQUE (dzial_id, nazwa)
);

ALTER TABLE maszyny
    ADD COLUMN IF NOT EXISTS sekcja_id BIGINT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'maszyny' AND constraint_name = 'fk_maszyny_sekcja'
    ) THEN
        ALTER TABLE maszyny
            ADD CONSTRAINT fk_maszyny_sekcja
            FOREIGN KEY (sekcja_id) REFERENCES sekcje(id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_sekcje_dzial_id ON sekcje(dzial_id);
CREATE INDEX IF NOT EXISTS idx_maszyny_sekcja_id ON maszyny(sekcja_id);

