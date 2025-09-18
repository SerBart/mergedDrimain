package drimer.drimain.model.enums;

/**
 * Status czynności / zadania w harmonogramie.
 * Trzymaj wartości w formacie UPPER_CASE_BEZ_POLSKICH_ZNAKÓW, żeby uniknąć problemów z URL / parsowaniem.
 */
public enum StatusHarmonogramu {
    PLANOWANE,
    W_TRAKCIE,
    BRAK_CZESCI,
    OCZEKIWANIE_NA_CZESC,
    ZAKONCZONE;

    /**
     * Czy status oznacza zakończenie procesu.
     */
    public boolean isFinal() {
        return this == ZAKONCZONE;
    }
}