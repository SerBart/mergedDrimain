CREATE TABLE IF NOT EXISTS maszyny_sekcje (
    maszyna_id BIGINT NOT NULL REFERENCES maszyny(id) ON DELETE CASCADE,
    sekcja_id BIGINT NOT NULL REFERENCES sekcje(id) ON DELETE CASCADE,
    PRIMARY KEY (maszyna_id, sekcja_id)
);

CREATE INDEX IF NOT EXISTS idx_maszyny_sekcje_maszyna_id ON maszyny_sekcje(maszyna_id);
CREATE INDEX IF NOT EXISTS idx_maszyny_sekcje_sekcja_id ON maszyny_sekcje(sekcja_id);

-- Migracja danych historycznych: sekcja główna maszyny trafia też do relacji many-to-many.
INSERT INTO maszyny_sekcje (maszyna_id, sekcja_id)
SELECT id, sekcja_id
FROM maszyny
WHERE sekcja_id IS NOT NULL
ON CONFLICT DO NOTHING;

