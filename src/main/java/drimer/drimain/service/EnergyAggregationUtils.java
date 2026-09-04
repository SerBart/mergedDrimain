package drimer.drimain.service;

import drimer.drimain.api.dto.EnergyHistoryPointDTO;
import drimer.drimain.model.EnergyReading;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class EnergyAggregationUtils {

    private EnergyAggregationUtils() {
    }

    static LocalDateTime bucketStart(LocalDateTime value, int bucketMinutes) {
        int normalized = Math.max(1, Math.min(bucketMinutes, 60));
        int minute = (value.getMinute() / normalized) * normalized;
        return value.withSecond(0).withNano(0).withMinute(minute);
    }

    static List<EnergyHistoryPointDTO> aggregateHistory(List<EnergyReading> readings, int bucketMinutes) {
        if (readings == null || readings.isEmpty()) {
            return List.of();
        }

        Map<LocalDateTime, List<EnergyReading>> grouped = new LinkedHashMap<>();
        readings.stream()
                .filter(r -> r.getRecordedAt() != null)
                .sorted(Comparator.comparing(EnergyReading::getRecordedAt))
                .forEach(reading -> {
                    LocalDateTime bucket = bucketStart(reading.getRecordedAt(), bucketMinutes);
                    grouped.computeIfAbsent(bucket, k -> new ArrayList<>()).add(reading);
                });

        List<EnergyHistoryPointDTO> points = new ArrayList<>();
        for (Map.Entry<LocalDateTime, List<EnergyReading>> entry : grouped.entrySet()) {
            List<EnergyReading> bucketReadings = entry.getValue();
            if (bucketReadings.isEmpty()) {
                continue;
            }

            List<EnergyReading> representativeReadings = latestReadingPerMachine(bucketReadings);
            if (representativeReadings.isEmpty()) {
                continue;
            }

            EnergyReading first = representativeReadings.get(0);
            EnergyReading last = representativeReadings.get(representativeReadings.size() - 1);
            BigDecimal totalPower = totalPower(representativeReadings);
            BigDecimal totalEnergy = totalEnergy(representativeReadings);

            EnergyHistoryPointDTO point = new EnergyHistoryPointDTO();
            point.setRecordedAt(OffsetDateTime.of(entry.getKey(), ZoneOffset.UTC));
            point.setPowerKw(totalPower);
            point.setEnergyKwhTotal(totalEnergy);
            point.setVoltageV(averageVoltage(representativeReadings));
            point.setCurrentA(averageCurrent(representativeReadings));
            point.setDeviceId(last.getDeviceId() != null ? last.getDeviceId() : first.getDeviceId());
            points.add(point);
        }

        return points;
    }

    private static List<EnergyReading> latestReadingPerMachine(List<EnergyReading> readings) {
        Map<Long, EnergyReading> latestByMachine = new LinkedHashMap<>();
        for (EnergyReading reading : readings) {
            if (reading == null || reading.getMaszyna() == null || reading.getMaszyna().getId() == null || reading.getRecordedAt() == null) {
                continue;
            }
            latestByMachine.merge(
                    reading.getMaszyna().getId(),
                    reading,
                    (current, candidate) -> candidate.getRecordedAt().isAfter(current.getRecordedAt()) ? candidate : current
            );
        }
        return latestByMachine.values().stream()
                .sorted(Comparator.comparing(EnergyReading::getRecordedAt))
                .toList();
    }

    static BigDecimal calculateEnergyDelta(List<EnergyReading> readings) {
        if (readings == null || readings.isEmpty()) {
            return BigDecimal.ZERO;
        }

        EnergyReading first = readings.stream()
                .filter(r -> r.getRecordedAt() != null)
                .min(Comparator.comparing(EnergyReading::getRecordedAt))
                .orElse(null);
        EnergyReading last = readings.stream()
                .filter(r -> r.getRecordedAt() != null)
                .max(Comparator.comparing(EnergyReading::getRecordedAt))
                .orElse(null);

        if (first == null || last == null) {
            return BigDecimal.ZERO;
        }

        if (first.getEnergyKwhTotal() != null && last.getEnergyKwhTotal() != null) {
            BigDecimal delta = last.getEnergyKwhTotal().subtract(first.getEnergyKwhTotal());
            return delta.max(BigDecimal.ZERO);
        }

        BigDecimal averagePower = averagePower(readings);
        long minutes = Math.max(1, java.time.Duration.between(first.getRecordedAt(), last.getRecordedAt()).toMinutes());
        BigDecimal hours = BigDecimal.valueOf(minutes).divide(BigDecimal.valueOf(60), 6, RoundingMode.HALF_UP);
        return averagePower.multiply(hours).max(BigDecimal.ZERO);
    }

    private static BigDecimal totalPower(List<EnergyReading> readings) {
        BigDecimal sum = BigDecimal.ZERO;
        for (EnergyReading reading : readings) {
            if (reading.getPowerKw() == null) {
                continue;
            }
            sum = sum.add(reading.getPowerKw());
        }
        return sum.max(BigDecimal.ZERO);
    }

    private static BigDecimal totalEnergy(List<EnergyReading> readings) {
        BigDecimal sum = BigDecimal.ZERO;
        for (EnergyReading reading : readings) {
            if (reading.getEnergyKwhTotal() == null) {
                continue;
            }
            sum = sum.add(reading.getEnergyKwhTotal());
        }
        return sum.max(BigDecimal.ZERO);
    }

                                                                                                                                                                private static BigDecimal averagePower(List<EnergyReading> readings) {
        BigDecimal sum = BigDecimal.ZERO;
        long count = 0;
        for (EnergyReading reading : readings) {
            if (reading.getPowerKw() == null) continue;
            sum = sum.add(reading.getPowerKw());
            count++;
        }
        if (count == 0) {
            return BigDecimal.ZERO;
        }
        return sum.divide(BigDecimal.valueOf(count), 3, RoundingMode.HALF_UP);
    }

    private static BigDecimal averageVoltage(List<EnergyReading> readings) {
        BigDecimal sum = BigDecimal.ZERO;
        long count = 0;
        for (EnergyReading reading : readings) {
            if (reading.getVoltageV() == null) continue;
            sum = sum.add(reading.getVoltageV());
            count++;
        }
        if (count == 0) {
            return BigDecimal.ZERO;
        }
        return sum.divide(BigDecimal.valueOf(count), 3, RoundingMode.HALF_UP);
    }

    private static BigDecimal averageCurrent(List<EnergyReading> readings) {
        BigDecimal sum = BigDecimal.ZERO;
        long count = 0;
        for (EnergyReading reading : readings) {
            if (reading.getCurrentA() == null) continue;
            sum = sum.add(reading.getCurrentA());
            count++;
        }
        if (count == 0) {
            return BigDecimal.ZERO;
        }
        return sum.divide(BigDecimal.valueOf(count), 3, RoundingMode.HALF_UP);
    }
}

