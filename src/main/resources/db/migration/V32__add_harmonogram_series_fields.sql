-- Add support for recurring maintenance plan series
ALTER TABLE harmonogramy
    ADD COLUMN IF NOT EXISTS series_id VARCHAR(64);

ALTER TABLE harmonogramy
    ADD COLUMN IF NOT EXISTS plan_end_date DATE;

CREATE INDEX IF NOT EXISTS idx_harmonogramy_series_id ON harmonogramy(series_id);

