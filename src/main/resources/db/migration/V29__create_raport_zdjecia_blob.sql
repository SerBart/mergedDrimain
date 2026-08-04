CREATE TABLE IF NOT EXISTS raport_zdjecia_blob (
    id BIGSERIAL PRIMARY KEY,
    raport_id BIGINT NOT NULL,
    stored_filename VARCHAR(300) NOT NULL,
    content_type VARCHAR(150),
    file_size BIGINT,
    data BYTEA NOT NULL,
    CONSTRAINT fk_raport_zdjecia_blob_raport
        FOREIGN KEY (raport_id)
        REFERENCES raporty(id)
        ON DELETE CASCADE,
    CONSTRAINT uk_raport_blob_file UNIQUE (raport_id, stored_filename)
);

CREATE INDEX IF NOT EXISTS idx_raport_zdjecia_blob_raport
    ON raport_zdjecia_blob(raport_id);

