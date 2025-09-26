-- V22: add optional machine assignment to parts
ALTER TABLE parts ADD COLUMN IF NOT EXISTS maszyna_id BIGINT;
DO $$ BEGIN
    ALTER TABLE parts
        ADD CONSTRAINT fk_parts_maszyna FOREIGN KEY (maszyna_id) REFERENCES maszyny(id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
CREATE INDEX IF NOT EXISTS idx_parts_maszyna ON parts(maszyna_id);

