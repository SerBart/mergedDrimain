-- Ujednolicenie nazw kolumn do snake_case, aby pasowały do @Column w encji Attachment

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='attachments' AND column_name='originalfilename') THEN
    EXECUTE 'ALTER TABLE attachments RENAME COLUMN originalfilename TO original_filename';
END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='attachments' AND column_name='storedfilename') THEN
    EXECUTE 'ALTER TABLE attachments RENAME COLUMN storedfilename TO stored_filename';
END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='attachments' AND column_name='contenttype') THEN
    EXECUTE 'ALTER TABLE attachments RENAME COLUMN contenttype TO content_type';
END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='attachments' AND column_name='sizebytes') THEN
    EXECUTE 'ALTER TABLE attachments RENAME COLUMN sizebytes TO file_size';
END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='attachments' AND column_name='createdat') THEN
    EXECUTE 'ALTER TABLE attachments RENAME COLUMN createdat TO created_at';
END IF;
END $$;

-- Upewnij się, że wymagane kolumny istnieją (idempotentnie)
ALTER TABLE attachments
    ADD COLUMN IF NOT EXISTS original_filename VARCHAR(512),
    ADD COLUMN IF NOT EXISTS stored_filename   VARCHAR(512),
    ADD COLUMN IF NOT EXISTS content_type      VARCHAR(255),
    ADD COLUMN IF NOT EXISTS file_size         BIGINT,
    ADD COLUMN IF NOT EXISTS created_at        TIMESTAMP;

-- Kolumny z V3 (bezpiecznie powtórzyć)
ALTER TABLE attachments
    ADD COLUMN IF NOT EXISTS checksum   VARCHAR(128),
    ADD COLUMN IF NOT EXISTS created_by VARCHAR(255);

-- Indeksy/unikalność
CREATE UNIQUE INDEX IF NOT EXISTS ux_attachments_stored_filename ON attachments(stored_filename);
CREATE INDEX IF NOT EXISTS idx_attachments_zgloszenie_id ON attachments(zgloszenie_id);

-- Opcjonalnie: constraints NOT NULL (zadziała, jeśli brak NULL-ów / świeża baza)
ALTER TABLE attachments
    ALTER COLUMN original_filename SET NOT NULL,
ALTER COLUMN stored_filename   SET NOT NULL,
  ALTER COLUMN content_type      SET NOT NULL,
  ALTER COLUMN file_size         SET NOT NULL,
  ALTER COLUMN created_at        SET NOT NULL;