-- Safety migration to ensure column exists even if V16 was applied earlier without it
ALTER TABLE harmonogramy ADD COLUMN IF NOT EXISTS duration_minutes INTEGER;

