package drimer.drimain.model.enums;

/**
 * Opcjonalny enum dla encji Zgloszenie (jeżeli używasz tam pola status).
 * Dodaj / usuń wartości wg potrzeb.
 */
public enum StatusZgloszenia {
    NOWE,
    WERYFIKACJA,
    W_TRAKCIE,
    BRAK_CZESCI,
    OCZEKIWANIE_NA_CZESC,
    ROZWIAZANE,
    ODRZUCONE,
    ZAMKNIETE;

    public boolean isClosed() {
        return this == ROZWIAZANE || this == ODRZUCONE || this == ZAMKNIETE;
    }
}