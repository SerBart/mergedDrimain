ALTER TABLE sekcje
    ADD COLUMN IF NOT EXISTS maszyna_id BIGINT;

UPDATE sekcje s
SET maszyna_id = map.machine_id
FROM (
    SELECT sekcja_id, MIN(id) AS machine_id
    FROM maszyny
    WHERE sekcja_id IS NOT NULL
    GROUP BY sekcja_id
) map
WHERE s.id = map.sekcja_id
  AND s.maszyna_id IS NULL;

UPDATE sekcje s
SET maszyna_id = map.machine_id
FROM (
    SELECT dzial_id, MIN(id) AS machine_id
    FROM maszyny
    WHERE dzial_id IS NOT NULL
    GROUP BY dzial_id
) map
WHERE s.dzial_id = map.dzial_id
  AND s.maszyna_id IS NULL;

UPDATE sekcje
SET maszyna_id = (SELECT MIN(id) FROM maszyny)
WHERE maszyna_id IS NULL
  AND EXISTS (SELECT 1 FROM maszyny);

DO $$
DECLARE
    old_fk_name TEXT;
BEGIN
    SELECT tc.constraint_name
    INTO old_fk_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
     AND tc.table_schema = kcu.table_schema
    WHERE tc.table_name = 'sekcje'
      AND tc.constraint_type = 'FOREIGN KEY'
      AND kcu.column_name = 'dzial_id'
    LIMIT 1;

    IF old_fk_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE sekcje DROP CONSTRAINT %I', old_fk_name);
    END IF;
END $$;

ALTER TABLE sekcje
    DROP CONSTRAINT IF EXISTS uk_sekcje_dzial_nazwa;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE table_name = 'sekcje'
          AND constraint_name = 'fk_sekcje_maszyna'
    ) THEN
        ALTER TABLE sekcje
            ADD CONSTRAINT fk_sekcje_maszyna
            FOREIGN KEY (maszyna_id) REFERENCES maszyny(id) ON DELETE CASCADE;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE table_name = 'sekcje'
          AND constraint_name = 'uk_sekcje_maszyna_nazwa'
    ) THEN
        ALTER TABLE sekcje
            ADD CONSTRAINT uk_sekcje_maszyna_nazwa UNIQUE (maszyna_id, nazwa);
    END IF;
END $$;

DROP INDEX IF EXISTS idx_sekcje_dzial_id;
CREATE INDEX IF NOT EXISTS idx_sekcje_maszyna_id ON sekcje(maszyna_id);

ALTER TABLE sekcje
    DROP COLUMN IF EXISTS dzial_id;

