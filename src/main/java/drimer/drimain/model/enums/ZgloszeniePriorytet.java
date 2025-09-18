package drimer.drimain.model.enums;

/**
 * Enum representing priority levels for Zgloszenie (Issues).
 * Ordered from lowest to highest priority for natural sorting.
 */
public enum ZgloszeniePriorytet {
    NISKI("Niski"),
    NORMALNY("Normalny"), 
    WYSOKI("Wysoki"),
    KRYTYCZNY("Krytyczny");

    private final String displayName;

    ZgloszeniePriorytet(String displayName) {
        this.displayName = displayName;
    }

    public String getDisplayName() {
        return displayName;
    }

    /**
     * Check if this priority is considered urgent (high or critical)
     */
    public boolean isUrgent() {
        return this == WYSOKI || this == KRYTYCZNY;
    }
}