package drimer.drimain.util;

import drimer.drimain.model.enums.StatusHarmonogramu;
import drimer.drimain.model.enums.StatusZgloszenia;

import java.util.EnumMap;
import java.util.Map;

/**
 * Pomocnicze mapowanie enum -> etykieta do wyświetlenia (np. w Thymeleaf).
 * Możesz zastąpić to mechanizmem i18n (messages.properties),
 * wtedy wystarczy w widoku: #{status.harmonogram.PLANOWANE}
 */
public final class StatusLabelUtil {

    private static final Map<StatusHarmonogramu, String> HARMONOGRAM_LABELS = new EnumMap<>(StatusHarmonogramu.class);
    private static final Map<StatusZgloszenia, String> ZGLOSZENIE_LABELS = new EnumMap<>(StatusZgloszenia.class);

    static {
        HARMONOGRAM_LABELS.put(StatusHarmonogramu.PLANOWANE, "Planowane");
        HARMONOGRAM_LABELS.put(StatusHarmonogramu.W_TRAKCIE, "W trakcie");
        HARMONOGRAM_LABELS.put(StatusHarmonogramu.BRAK_CZESCI, "Brak części");
        HARMONOGRAM_LABELS.put(StatusHarmonogramu.OCZEKIWANIE_NA_CZESC, "Oczekiwanie na część");
        HARMONOGRAM_LABELS.put(StatusHarmonogramu.ZAKONCZONE, "Zakończone");

        ZGLOSZENIE_LABELS.put(StatusZgloszenia.NOWE, "Nowe");
        ZGLOSZENIE_LABELS.put(StatusZgloszenia.WERYFIKACJA, "W weryfikacji");
        ZGLOSZENIE_LABELS.put(StatusZgloszenia.W_TRAKCIE, "W trakcie");
        ZGLOSZENIE_LABELS.put(StatusZgloszenia.BRAK_CZESCI, "Brak części");
        ZGLOSZENIE_LABELS.put(StatusZgloszenia.OCZEKIWANIE_NA_CZESC, "Oczekiwanie na część");
        ZGLOSZENIE_LABELS.put(StatusZgloszenia.ROZWIAZANE, "Rozwiązane");
        ZGLOSZENIE_LABELS.put(StatusZgloszenia.ODRZUCONE, "Odrzucone");
        ZGLOSZENIE_LABELS.put(StatusZgloszenia.ZAMKNIETE, "Zamknięte");
    }

    private StatusLabelUtil() {}

    public static String label(StatusHarmonogramu status) {
        return status == null ? "" : HARMONOGRAM_LABELS.getOrDefault(status, status.name());
    }

    public static String label(StatusZgloszenia status) {
        return status == null ? "" : ZGLOSZENIE_LABELS.getOrDefault(status, status.name());
    }
}