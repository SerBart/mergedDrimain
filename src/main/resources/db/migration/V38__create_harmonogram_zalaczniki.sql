-- Create attachments table for harmonogramy (PDF / images stored inline in DB)
CREATE TABLE IF NOT EXISTS harmonogram_zalaczniki (
    harmonogram_id BIGINT NOT NULL,
    sciezka_zalacznika TEXT NOT NULL,
    CONSTRAINT fk_harmonogram_zalaczniki_harmonogram
        FOREIGN KEY (harmonogram_id) REFERENCES harmonogramy(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_harmonogram_zalaczniki_harmonogram_id
    ON harmonogram_zalaczniki(harmonogram_id);

