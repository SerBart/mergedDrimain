-- Tworzy tabelę załączników powiązaną ze zgłoszeniem
CREATE TABLE attachments (
                             id BIGSERIAL PRIMARY KEY,
                             zgloszenie_id BIGINT NOT NULL REFERENCES zgloszenia(id) ON DELETE CASCADE,
                             originalFilename VARCHAR(512) NOT NULL,
                             storedFilename   VARCHAR(512) NOT NULL,
                             contentType      VARCHAR(255),
                             sizeBytes        BIGINT,
                             createdAt        TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_attachments_zgloszenie_id ON attachments(zgloszenie_id);