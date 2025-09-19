CREATE TABLE IF NOT EXISTS czesci_magazyn (
    id BIGSERIAL PRIMARY KEY,
    nazwa              VARCHAR(255),
    numer_katalogowy   VARCHAR(255),
    dostawca           VARCHAR(255),
    producent          VARCHAR(255),
    ilosc              INTEGER,
    data_dodania       DATE
);