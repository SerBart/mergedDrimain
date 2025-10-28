package drimer.drimain.security;

import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * Katalog wspieranych "kafelków" (modułów) aplikacji.
 */
public final class ModulesCatalog {
    private ModulesCatalog() {}

    // Zachowujemy kolejność do UI
    public static final List<String> ALLOWED = List.of(
            "Zgloszenia",
            "Raporty",
            "Harmonogramy",
            "Czesci",
            "Instrukcje"
    );

    public static boolean isAllowed(String value) {
        if (value == null || value.isBlank()) return false;
        return ALLOWED.stream().anyMatch(v -> v.equalsIgnoreCase(value));
    }

    /**
     * Zwraca zbiór kanonicznych nazw (jak w ALLOWED) dla podanych wejściowych
     * nazw modułów (case-insensitive). Nieznane wartości są pomijane.
     */
    public static Set<String> normalizeAndFilter(Set<String> input) {
        if (input == null || input.isEmpty()) return Collections.emptySet();
        Set<String> out = new LinkedHashSet<>();
        for (String in : input) {
            if (in == null) continue;
            for (String canon : ALLOWED) {
                if (canon.equalsIgnoreCase(in.trim())) {
                    out.add(canon);
                    break;
                }
            }
        }
        return out;
    }
}

