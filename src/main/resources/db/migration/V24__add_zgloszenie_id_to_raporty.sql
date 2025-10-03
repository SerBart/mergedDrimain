-- Add zgloszenie_id to raporty for linking reports to source requests (idempotency)
ALTER TABLE raporty ADD COLUMN IF NOT EXISTS zgloszenie_id BIGINT;
CREATE UNIQUE INDEX IF NOT EXISTS ux_raporty_zgloszenie_id ON raporty (zgloszenie_id);

