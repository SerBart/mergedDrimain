CREATE TABLE IF NOT EXISTS harmonogramy (
    id BIGSERIAL PRIMARY KEY,
    data        DATE,
    opis        VARCHAR(255),
    maszyna_id  BIGINT,
    osoba_id    BIGINT,
    status      VARCHAR(40) NOT NULL,

    CONSTRAINT fk_harmonogramy_maszyna
        FOREIGN KEY (maszyna_id) REFERENCES maszyny(id),
    CONSTRAINT fk_harmonogramy_osoba
        FOREIGN KEY (osoba_id) REFERENCES osoby(id)
);

CREATE INDEX IF NOT EXISTS idx_harmonogramy_maszyna_id ON harmonogramy(maszyna_id);
CREATE INDEX IF NOT EXISTS idx_harmonogramy_osoba_id   ON harmonogramy(osoba_id);