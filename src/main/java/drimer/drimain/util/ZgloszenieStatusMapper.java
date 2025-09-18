package drimer.drimain.util;

import drimer.drimain.model.enums.ZgloszenieStatus;

public final class ZgloszenieStatusMapper {
    private ZgloszenieStatusMapper(){}

    public static ZgloszenieStatus map(String raw) {
        if (raw == null || raw.isBlank()) return null;
        String v = raw.trim().toUpperCase();
        switch (v) {
            case "NOWE": return ZgloszenieStatus.OPEN;
            case "W_TOKU": case "WTOKU": return ZgloszenieStatus.IN_PROGRESS;
            case "OCZEKUJE": case "HOLD": return ZgloszenieStatus.ON_HOLD;
            case "ZAKONCZONE": case "DONE": return ZgloszenieStatus.DONE;
            case "ODRZUCONE": case "REJECTED": return ZgloszenieStatus.REJECTED;
            default:
                try { return ZgloszenieStatus.valueOf(v); } catch (Exception e) { return null; }
        }
    }
}