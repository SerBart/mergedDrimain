CREATE TABLE roles (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(64) UNIQUE NOT NULL
);

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(120) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE user_roles (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

CREATE TABLE dzialy (
    id BIGSERIAL PRIMARY KEY,
    nazwa VARCHAR(255) NOT NULL
);

CREATE TABLE maszyny (
    id BIGSERIAL PRIMARY KEY,
    nazwa VARCHAR(255),
    kod VARCHAR(255),
    lokalizacja VARCHAR(255)
);

CREATE TABLE osoby (
    id BIGSERIAL PRIMARY KEY,
    imie VARCHAR(255),
    nazwisko VARCHAR(255),
    stanowisko VARCHAR(255),
    dzial_id BIGINT REFERENCES dzialy(id)
);

CREATE TABLE parts (
    id BIGSERIAL PRIMARY KEY,
    nazwa VARCHAR(255),
    kod VARCHAR(255),
    kategoria VARCHAR(255),
    ilosc INTEGER,
    minIlosc INTEGER,
    jednostka VARCHAR(32)
);

CREATE TABLE raporty (
    id BIGSERIAL PRIMARY KEY,
    maszyna_id BIGINT REFERENCES maszyny(id),
    typNaprawy VARCHAR(255),
    opis VARCHAR(4000),
    osoba_id BIGINT REFERENCES osoby(id),
    status VARCHAR(40),
    dataNaprawy DATE,
    czasOd TIME,
    czasDo TIME
);

CREATE TABLE part_usage (
    id BIGSERIAL PRIMARY KEY,
    raport_id BIGINT REFERENCES raporty(id) ON DELETE CASCADE,
    part_id BIGINT REFERENCES parts(id),
    ilosc INTEGER
);

CREATE TABLE zgloszenia (
    id BIGSERIAL PRIMARY KEY,
    dataGodzina TIMESTAMP,
    typ VARCHAR(255),
    imie VARCHAR(255),
    nazwisko VARCHAR(255),
    status VARCHAR(40),
    opis VARCHAR(4000),
    photo BYTEA
);