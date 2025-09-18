package drimer.drimain.util;

import drimer.drimain.model.enums.RaportStatus;

import java.util.Locale;
import java.util.Map;

import static java.util.Map.entry;

/**
 * Mapowanie różnych wariantów tekstowych na RaportStatus.
 * Używa Map.ofEntries (dowolna liczba wpisów) zamiast Map.of (max 10 par).
 */
public final class RaportStatusMapper {

    // Słownik znormalizowanych kluczy -> enum
    private static final Map<String, RaportStatus> DIRECT = Map.ofEntries(
            entry("OTWARTY", RaportStatus.NOWY),
            entry("NOWY", RaportStatus.NOWY),
            entry("NEW", RaportStatus.NOWY),

            entry("WTOKU", RaportStatus.W_TOKU),
            entry("W_TOKU", RaportStatus.W_TOKU),
            entry("INPROGRESS", RaportStatus.W_TOKU),

            entry("OCZEKUJE", RaportStatus.OCZEKUJE_CZESCI),
            entry("OCZEKUJE_CZESCI", RaportStatus.OCZEKUJE_CZESCI),
            entry("OCZEKUJE_NA_CZESCI", RaportStatus.OCZEKUJE_CZESCI),
            entry("WAITINGPARTS", RaportStatus.OCZEKUJE_CZESCI),

            entry("ZAKONCZONE", RaportStatus.ZAKONCZONE),
            entry("ZAKONCZONY", RaportStatus.ZAKONCZONE),
            entry("DONE", RaportStatus.ZAKONCZONE),
            entry("CLOSED", RaportStatus.ZAKONCZONE),

            entry("ANULOWANE", RaportStatus.ANULOWANE),
            entry("ANULOWANY", RaportStatus.ANULOWANE),
            entry("CANCELED", RaportStatus.ANULOWANE),
            entry("CANCELLED", RaportStatus.ANULOWANE)
    );

    private RaportStatusMapper() {}

    public static RaportStatus map(String raw) {
        if (raw == null || raw.isBlank()) return null;

        String normalized = normalize(raw);
        RaportStatus mapped = DIRECT.get(normalized);
        if (mapped != null) return mapped;

        // Ostateczna próba: ktoś mógł podać dokładną nazwę enuma
        try {
            return RaportStatus.valueOf(raw.trim().toUpperCase(Locale.ROOT));
        } catch (Exception ignored) {
            return null;
        }
    }

    /**
     * Normalizacja:
     * - trim & upper
     * - transliteracja polskich znaków
     * - zamiana spacji / myślników na podkreślenie
     * - usunięcie znaków nie-alfa-numerycznych (poza _)
     * - redukcja wielokrotnych podkreśleń
     */
    private static String normalize(String in) {
        String s = in.trim().toUpperCase(Locale.ROOT)
                .replace('Ł','L')
                .replace('Ś','S')
                .replace('Ć','C')
                .replace('Ę','E')
                .replace('Ó','O')
                .replace('Ń','N')
                .replace('Ż','Z')
                .replace('Ź','Z');

        s = s.replaceAll("[\\s\\-]+", "_");   // spacje / myślniki → _
        s = s.replaceAll("[^A-Z0-9_]", "");    // wywal inne znaki
        s = s.replaceAll("_+", "_");           // zredukuj wielokrotne _
        return s;
    }
}