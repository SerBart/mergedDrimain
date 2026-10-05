package drimer.drimain.service;

import drimer.drimain.api.dto.EnergyHistoryPointDTO;
import drimer.drimain.model.EnergyReading;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class EnergyAggregationUtils {

    // Guardrails for rejecting unrealistic meter-total jumps caused by bad mappings.
    private static final BigDecimal SPIKE_MULTIPLIER = new BigDecimal("4");
    private static final BigDecimal SPIKE_MARGIN_KWH = new BigDecimal("0.5");
    private static final BigDecimal DEFAULT_MAX_POWER_KW = new BigDecimal("500");

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

        Map<Long, BigDecimal> baselineEnergyByMachine = firstEnergyByMachine(readings);

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
            BigDecimal totalEnergy = relativeEnergySinceRangeStart(representativeReadings, baselineEnergyByMachine);

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

        List<EnergyReading> ordered = readings.stream()
                .filter(r -> r.getRecordedAt() != null && r.getEnergyKwhTotal() != null)
                .sorted(Comparator.comparing(EnergyReading::getRecordedAt))
                .toList();

        if (ordered.size() < 2) {
            return BigDecimal.ZERO;
        }

        BigDecimal deltaSum = BigDecimal.ZERO;
        EnergyReading previous = ordered.get(0);
        for (int i = 1; i < ordered.size(); i++) {
            EnergyReading current = ordered.get(i);
            BigDecimal step = current.getEnergyKwhTotal().subtract(previous.getEnergyKwhTotal());

            if (step.compareTo(BigDecimal.ZERO) <= 0) {
                previous = current;
                continue;
            }

            if (isUnrealisticStep(previous, current, step)) {
                previous = current;
                continue;
            }

            deltaSum = deltaSum.add(step);
            previous = current;
        }

        if (deltaSum.compareTo(BigDecimal.ZERO) > 0) {
            return deltaSum;
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

    private static boolean isUnrealisticStep(EnergyReading previous, EnergyReading current, BigDecimal stepKwh) {
        if (previous == null || current == null || previous.getRecordedAt() == null || current.getRecordedAt() == null) {
            return false;
        }

        long seconds = Math.max(1L, Duration.between(previous.getRecordedAt(), current.getRecordedAt()).getSeconds());
        BigDecimal hours = BigDecimal.valueOf(seconds)
                .divide(BigDecimal.valueOf(3600), 6, RoundingMode.HALF_UP);

        BigDecimal referencePower = averagePositive(previous.getPowerKw(), current.getPowerKw());
        if (referencePower == null) {
            referencePower = DEFAULT_MAX_POWER_KW;
        }

        BigDecimal plausibleMax = referencePower
                .multiply(hours)
                .multiply(SPIKE_MULTIPLIER)
                .add(SPIKE_MARGIN_KWH);

        return stepKwh.compareTo(plausibleMax) > 0;
    }

    private static BigDecimal averagePositive(BigDecimal a, BigDecimal b) {
        boolean validA = a != null && a.compareTo(BigDecimal.ZERO) > 0;
        boolean validB = b != null && b.compareTo(BigDecimal.ZERO) > 0;
        if (validA && validB) {
            return a.add(b).divide(BigDecimal.valueOf(2), 6, RoundingMode.HALF_UP);
        }
        if (validA) {
            return a;
        }
        if (validB) {
            return b;
        }
        return null;
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

    private static BigDecimal relativeEnergySinceRangeStart(List<EnergyReading> readings, Map<Long, BigDecimal> baselineEnergyByMachine) {
        BigDecimal sum = BigDecimal.ZERO;
        for (EnergyReading reading : readings) {
            if (reading == null || reading.getMaszyna() == null || reading.getMaszyna().getId() == null || reading.getEnergyKwhTotal() == null) {
                continue;
            }
            BigDecimal baseline = baselineEnergyByMachine.get(reading.getMaszyna().getId());
            if (baseline == null) {
                continue;
            }
            BigDecimal delta = reading.getEnergyKwhTotal().subtract(baseline).max(BigDecimal.ZERO);
            sum = sum.add(delta);
        }
        return sum.max(BigDecimal.ZERO);
    }

    private static Map<Long, BigDecimal> firstEnergyByMachine(List<EnergyReading> readings) {
        Map<Long, BigDecimal> baseline = new LinkedHashMap<>();
        readings.stream()
                .filter(r -> r != null && r.getRecordedAt() != null)
                .sorted(Comparator.comparing(EnergyReading::getRecordedAt))
                .forEach(reading -> {
                    if (reading.getMaszyna() == null || reading.getMaszyna().getId() == null || reading.getEnergyKwhTotal() == null) {
                        return;
                    }
                    baseline.putIfAbsent(reading.getMaszyna().getId(), reading.getEnergyKwhTotal());
                });
        return baseline;
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

