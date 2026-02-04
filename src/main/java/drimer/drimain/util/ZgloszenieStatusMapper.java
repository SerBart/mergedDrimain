package drimer.drimain.util;

import drimer.drimain.model.enums.ZgloszenieStatus;

public final class ZgloszenieStatusMapper {
    private ZgloszenieStatusMapper(){}

    public static ZgloszenieStatus map(String raw) {
        if (raw == null || raw.isBlank()) return null;
        String v = raw.trim().toUpperCase();
        switch (v) {
            case "NOWE": case "OPEN": return ZgloszenieStatus.OPEN;
            case "W_TOKU": case "WTOKU": case "W TOKU":
            case "ROZPOCZĘCIE NAPRAWY": case "ROZPOCZECIE NAPRAWY":
            case "ROZPOCZĘCIE_NAPRAWY": case "ROZPOCZECIE_NAPRAWY":
            case "ROZPOCZETO": case "ROZPOCZĘTO":
            case "IN_PROGRESS":
                return ZgloszenieStatus.IN_PROGRESS;
            case "OCZEKUJE": case "HOLD": case "ON_HOLD": case "PRZERWANE": return ZgloszenieStatus.ON_HOLD;
            case "ZAKONCZONE": case "DONE": case "ZAKOŃCZONE": case "ZAMKNIĘTE": case "ZAMKNIETE": return ZgloszenieStatus.DONE;
            case "ODRZUCONE": case "REJECTED": return ZgloszenieStatus.REJECTED;
            default:
                try { return ZgloszenieStatus.valueOf(v); } catch (Exception e) { return null; }
        }
    }
}