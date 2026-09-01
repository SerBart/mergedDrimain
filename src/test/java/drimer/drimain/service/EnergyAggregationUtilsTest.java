package drimer.drimain.service;

import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.assertEquals;

class EnergyAggregationUtilsTest {

    @Test
    void bucketStartRoundsDownToQuarterHour() {
        LocalDateTime input = LocalDateTime.of(2026, 8, 28, 10, 17, 45);
        assertEquals(LocalDateTime.of(2026, 8, 28, 10, 15), EnergyAggregationUtils.bucketStart(input, 15));
    }

    @Test
    void bucketStartWorksForOtherIntervals() {
        LocalDateTime input = LocalDateTime.of(2026, 8, 28, 10, 47, 0);
        assertEquals(LocalDateTime.of(2026, 8, 28, 10, 30), EnergyAggregationUtils.bucketStart(input, 30));
    }
}

