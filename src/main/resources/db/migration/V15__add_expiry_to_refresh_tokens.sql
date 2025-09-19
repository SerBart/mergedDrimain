ALTER TABLE refresh_tokens
  ADD COLUMN IF NOT EXISTS expiry TIMESTAMP;

-- Opcjonalne uzupełnienie z wcześniejszej kolumny
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='refresh_tokens' AND column_name='expires_at'
  ) THEN
    EXECUTE 'UPDATE refresh_tokens SET expiry = expires_at WHERE expiry IS NULL';
  END IF;
END $$;

-- Opcjonalny indeks pod wygaszanie
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expiry ON refresh_tokens(expiry);