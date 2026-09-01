package drimer.drimain.service;

public enum EnergyScopeType {
    TOTAL,
    DZIAL,
    MASZYNA;

    public static EnergyScopeType from(String value) {
        if (value == null || value.isBlank()) {
            return TOTAL;
        }
        try {
            return EnergyScopeType.valueOf(value.trim().toUpperCase());
        } catch (IllegalArgumentException ex) {
            return TOTAL;
        }
    }
}

