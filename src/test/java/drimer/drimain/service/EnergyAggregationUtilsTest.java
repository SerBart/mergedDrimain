package drimer.drimain.service;

import drimer.drimain.model.EnergyReading;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

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

    @Test
    void calculateEnergyDeltaUsesBaselineReadingFromBeforeMidnight() {
        EnergyReading beforeMidnight = reading(LocalDateTime.of(2026, 9, 8, 23, 55), "100.000");
        EnergyReading afterMidnight = reading(LocalDateTime.of(2026, 9, 9, 0, 30), "100.400");
        EnergyReading oneAm = reading(LocalDateTime.of(2026, 9, 9, 1, 0), "100.900");

        assertEquals(
                new BigDecimal("0.900"),
                EnergyAggregationUtils.calculateEnergyDelta(List.of(beforeMidnight, afterMidnight, oneAm))
        );
    }

    @Test
    void calculateEnergyDeltaNeverReturnsNegativeValue() {
        EnergyReading first = reading(LocalDateTime.of(2026, 9, 9, 0, 30), "100.900");
        EnergyReading last = reading(LocalDateTime.of(2026, 9, 9, 1, 0), "100.400");

        assertEquals(BigDecimal.ZERO, EnergyAggregationUtils.calculateEnergyDelta(List.of(first, last)));
    }

    private EnergyReading reading(LocalDateTime recordedAt, String energyTotal) {
        EnergyReading reading = new EnergyReading();
        reading.setRecordedAt(recordedAt);
        reading.setEnergyKwhTotal(new BigDecimal(energyTotal));
        reading.setPowerKw(BigDecimal.ONE);
        return reading;
    }
}

