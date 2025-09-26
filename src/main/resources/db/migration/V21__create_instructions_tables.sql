-- V21: instructions feature
CREATE TABLE IF NOT EXISTS instructions (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description VARCHAR(4000),
    maszyna_id BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    created_by VARCHAR(255),
    CONSTRAINT fk_instructions_maszyna FOREIGN KEY (maszyna_id) REFERENCES maszyny(id)
);
CREATE INDEX IF NOT EXISTS idx_instructions_maszyna ON instructions(maszyna_id);
CREATE INDEX IF NOT EXISTS idx_instructions_created_at ON instructions(created_at);

CREATE TABLE IF NOT EXISTS instruction_parts (
    id BIGSERIAL PRIMARY KEY,
    instruction_id BIGINT NOT NULL,
    part_id BIGINT NOT NULL,
    ilosc INTEGER,
    CONSTRAINT fk_instruction_parts_instruction FOREIGN KEY (instruction_id) REFERENCES instructions(id) ON DELETE CASCADE,
    CONSTRAINT fk_instruction_parts_part FOREIGN KEY (part_id) REFERENCES parts(id)
);
CREATE INDEX IF NOT EXISTS idx_instruction_parts_instruction ON instruction_parts(instruction_id);
CREATE INDEX IF NOT EXISTS idx_instruction_parts_part ON instruction_parts(part_id);

CREATE TABLE IF NOT EXISTS instruction_attachments (
    id BIGSERIAL PRIMARY KEY,
    instruction_id BIGINT NOT NULL,
    original_filename VARCHAR(1024) NOT NULL,
    stored_filename VARCHAR(1024) NOT NULL UNIQUE,
    content_type VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL,
    checksum VARCHAR(128),
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    created_by VARCHAR(255),
    CONSTRAINT fk_instruction_attachments_instruction FOREIGN KEY (instruction_id) REFERENCES instructions(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_instruction_attachments_instruction ON instruction_attachments(instruction_id);

