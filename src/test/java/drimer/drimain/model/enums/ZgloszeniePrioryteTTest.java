package drimer.drimain.model.enums;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Test class for ZgloszeniePriorytet enum
 */
class ZgloszeniePrioryteTTest {

    @Test
    void testEnumValues() {
        assertEquals(4, ZgloszeniePriorytet.values().length);
        assertEquals("NISKI", ZgloszeniePriorytet.NISKI.name());
        assertEquals("NORMALNY", ZgloszeniePriorytet.NORMALNY.name());
        assertEquals("WYSOKI", ZgloszeniePriorytet.WYSOKI.name());
        assertEquals("KRYTYCZNY", ZgloszeniePriorytet.KRYTYCZNY.name());
    }

    @Test
    void testDisplayNames() {
        assertEquals("Niski", ZgloszeniePriorytet.NISKI.getDisplayName());
        assertEquals("Normalny", ZgloszeniePriorytet.NORMALNY.getDisplayName());
        assertEquals("Wysoki", ZgloszeniePriorytet.WYSOKI.getDisplayName());
        assertEquals("Krytyczny", ZgloszeniePriorytet.KRYTYCZNY.getDisplayName());
    }

    @Test
    void testIsUrgent() {
        assertFalse(ZgloszeniePriorytet.NISKI.isUrgent());
        assertFalse(ZgloszeniePriorytet.NORMALNY.isUrgent());
        assertTrue(ZgloszeniePriorytet.WYSOKI.isUrgent());
        assertTrue(ZgloszeniePriorytet.KRYTYCZNY.isUrgent());
    }
}