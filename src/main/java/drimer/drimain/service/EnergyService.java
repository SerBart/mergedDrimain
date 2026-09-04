package drimer.drimain.service;

import drimer.drimain.api.dto.EnergyHistoryPointDTO;
import drimer.drimain.api.dto.EnergyMachineSummaryDTO;
import drimer.drimain.api.dto.EnergyOverviewDTO;
import drimer.drimain.api.dto.EnergyReadingIngestRequest;
import drimer.drimain.model.EnergyReading;
import drimer.drimain.model.Maszyna;
import drimer.drimain.repository.EnergyReadingRepository;
import drimer.drimain.repository.MaszynaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
@Slf4j
public class EnergyService {

    private static final long DEFAULT_LIVE_STALE_SECONDS = 20L;

    private final EnergyReadingRepository energyReadingRepository;
    private final MaszynaRepository maszynaRepository;
    private final Map<String, SseEmitter> energySubscriptions = new ConcurrentHashMap<>();

    @Value("${app.energy.live-stale-seconds:20}")
    private long liveStaleSeconds;

    @Value("${app.energy.sse.client-timeout-ms:180000}")
    private long energySseClientTimeoutMs;

    @Transactional
    public EnergyReading ingest(EnergyReadingIngestRequest req) {
        Maszyna maszyna = maszynaRepository.findById(req.getMaszynaId())
                .orElseThrow(() -> new IllegalArgumentException("Maszyna not found"));

        EnergyReading reading = new EnergyReading();
        reading.setMaszyna(maszyna);
        reading.setDeviceId(req.getDeviceId().trim());
        reading.setRecordedAt(req.getRecordedAt().withOffsetSameInstant(ZoneOffset.UTC).toLocalDateTime());
        reading.setPowerKw(req.getPowerKw());
        reading.setEnergyKwhTotal(req.getEnergyKwhTotal());
        reading.setVoltageV(req.getVoltageV());
        reading.setCurrentA(req.getCurrentA());
        EnergyReading saved = energyReadingRepository.save(reading);
        broadcastUpdate();
        return saved;
    }

    @Transactional(readOnly = true)
    public EnergyOverviewDTO overview(int days) {
        int normalizedDays = normalizeDays(days);
        LocalDate today = LocalDate.now();
        LocalDate startDate = today.minusDays(normalizedDays - 1L);
        LocalDateTime start = startDate.atStartOfDay();
        LocalDateTime endExclusive = today.plusDays(1).atStartOfDay();
        LocalDateTime now = LocalDateTime.now(ZoneOffset.UTC);
        LocalDateTime activeThreshold = now.minusMinutes(30);

        List<EnergyReading> readings = energyReadingRepository.findByRecordedAtBetweenOrderByRecordedAtAsc(start, endExclusive);
        Map<Long, List<EnergyReading>> grouped = new LinkedHashMap<>();
        for (EnergyReading reading : readings) {
            if (reading.getMaszyna() == null || reading.getMaszyna().getId() == null) {
                continue;
            }
            grouped.computeIfAbsent(reading.getMaszyna().getId(), k -> new ArrayList<>()).add(reading);
        }

        List<EnergyMachineSummaryDTO> machines = new ArrayList<>();
        BigDecimal totalPowerKw = BigDecimal.ZERO;
        BigDecimal todayEnergyKwh = BigDecimal.ZERO;
        long activeMachines = 0;

        for (Map.Entry<Long, List<EnergyReading>> entry : grouped.entrySet()) {
            List<EnergyReading> machineReadings = entry.getValue();
            if (machineReadings.isEmpty()) continue;

            EnergyReading latest = machineReadings.stream()
                    .filter(r -> r.getRecordedAt() != null)
                    .max(Comparator.comparing(EnergyReading::getRecordedAt))
                    .orElse(machineReadings.get(machineReadings.size() - 1));
            List<EnergyReading> todayReadings = machineReadings.stream()
                    .filter(r -> r.getRecordedAt() != null && !r.getRecordedAt().isBefore(start))
                    .toList();
            BigDecimal deltaToday = EnergyAggregationUtils.calculateEnergyDelta(todayReadings);

            EnergyMachineSummaryDTO dto = new EnergyMachineSummaryDTO();
            dto.setMaszynaId(entry.getKey());
            dto.setMaszynaNazwa(latest.getMaszyna() != null ? latest.getMaszyna().getNazwa() : "Maszyna #" + entry.getKey());
            dto.setDeviceId(latest.getDeviceId());
            dto.setLastRecordedAt(toOffsetUtc(latest.getRecordedAt()));
            boolean fresh = isFresh(latest, now);
            dto.setPowerKw(fresh && latest.getPowerKw() != null ? latest.getPowerKw() : BigDecimal.ZERO);
            dto.setEnergyKwhTotal(fresh && latest.getEnergyKwhTotal() != null ? latest.getEnergyKwhTotal() : BigDecimal.ZERO);
            dto.setTodayEnergyKwh(deltaToday);
            dto.setReadingsCount(machineReadings.size());
            machines.add(dto);

            totalPowerKw = totalPowerKw.add(dto.getPowerKw() != null ? dto.getPowerKw() : BigDecimal.ZERO);
            todayEnergyKwh = todayEnergyKwh.add(deltaToday);
            if (fresh && latest.getRecordedAt() != null && !latest.getRecordedAt().isBefore(activeThreshold)) {
                activeMachines++;
            }
        }

        machines.sort(Comparator.comparing(EnergyMachineSummaryDTO::getMaszynaNazwa, String.CASE_INSENSITIVE_ORDER));

        EnergyOverviewDTO overview = new EnergyOverviewDTO();
        overview.setZakresDni(normalizedDays);
        overview.setBucketMinutes(15);
        overview.setGeneratedAt(OffsetDateTime.now(ZoneOffset.UTC));
        overview.setTotalPowerKw(totalPowerKw.max(BigDecimal.ZERO));
        overview.setTodayEnergyKwh(todayEnergyKwh.max(BigDecimal.ZERO));
        overview.setActiveMachines(activeMachines);
        overview.setTotalMachines(maszynaRepository.count());
        overview.setMachines(machines);
        return overview;
    }

    @Transactional(readOnly = true)
    public EnergyOverviewDTO overview(EnergyScopeType scope, Long dzialId, Long maszynaId, int days) {
        return overview(days);
    }

    @Transactional(readOnly = true)
    public List<EnergyHistoryPointDTO> history(EnergyScopeType scope, Long dzialId, Long maszynaId, int days, int bucketMinutes) {
        if (maszynaId != null) {
            return history(maszynaId, days, bucketMinutes);
        }

        int normalizedDays = normalizeDays(days);
        int normalizedBucketMinutes = normalizeBucketMinutes(bucketMinutes);
        LocalDate today = LocalDate.now();
        LocalDate startDate = today.minusDays(normalizedDays - 1L);
        LocalDateTime start = startDate.atStartOfDay();
        LocalDateTime endExclusive = today.plusDays(1).atStartOfDay();

        List<EnergyReading> readings;
        if (scope == EnergyScopeType.DZIAL && dzialId != null) {
            List<Maszyna> machines = maszynaRepository.findByDzial_Id(dzialId);
            if (machines.isEmpty()) {
                return List.of();
            }
            Map<Long, Maszyna> machinesById = new LinkedHashMap<>();
            for (Maszyna maszyna : machines) {
                if (maszyna != null && maszyna.getId() != null) {
                    machinesById.put(maszyna.getId(), maszyna);
                }
            }
            if (machinesById.isEmpty()) {
                return List.of();
            }
            readings = energyReadingRepository.findByRecordedAtBetweenOrderByRecordedAtAsc(start, endExclusive).stream()
                    .filter(r -> r.getMaszyna() != null && r.getMaszyna().getId() != null && machinesById.containsKey(r.getMaszyna().getId()))
                    .toList();
        } else {
            readings = energyReadingRepository.findByRecordedAtBetweenOrderByRecordedAtAsc(start, endExclusive);
        }
        return EnergyAggregationUtils.aggregateHistory(readings, normalizedBucketMinutes);
    }

    @Transactional
    public int deleteReadingsForMachine(Long maszynaId, LocalDateTime from, LocalDateTime to) {
        if (maszynaId == null) {
            throw new IllegalArgumentException("MaszynaId jest wymagane");
        }

        if (from != null && to != null) {
            if (from.isAfter(to)) {
                throw new IllegalArgumentException("'from' nie może być późniejsze niż 'to'");
            }
            return energyReadingRepository.deleteByMaszynaIdAndRecordedAtBetween(maszynaId, from, to);
        }

        if (from == null && to == null) {
            return energyReadingRepository.deleteByMaszynaId(maszynaId);
        }

        throw new IllegalArgumentException("Podaj oba parametry 'from' i 'to' albo nie podawaj żadnego");
    }

    @Transactional(readOnly = true)
    public List<EnergyHistoryPointDTO> history(Long maszynaId, int days, int bucketMinutes) {
        int normalizedDays = normalizeDays(days);
        int normalizedBucketMinutes = normalizeBucketMinutes(bucketMinutes);
        LocalDate today = LocalDate.now();
        LocalDate startDate = today.minusDays(normalizedDays - 1L);
        LocalDateTime start = startDate.atStartOfDay();
        LocalDateTime endExclusive = today.plusDays(1).atStartOfDay();

        List<EnergyReading> readings = energyReadingRepository.findByMaszyna_IdAndRecordedAtBetweenOrderByRecordedAtAsc(maszynaId, start, endExclusive);
        return EnergyAggregationUtils.aggregateHistory(readings, normalizedBucketMinutes);
    }

    @Transactional(readOnly = true)
    public List<EnergyMachineSummaryDTO> latestMachines() {
        return overview(1).getMachines();
    }

    public SseEmitter subscribeToUpdates(String scope, Long dzialId, Long maszynaId) {
        long timeoutMs = Math.max(30_000L, energySseClientTimeoutMs);
        SseEmitter emitter = new SseEmitter(timeoutMs);
        String subscriptionId = UUID.randomUUID().toString();
        energySubscriptions.put(subscriptionId, emitter);

        emitter.onCompletion(() -> energySubscriptions.remove(subscriptionId));
        emitter.onTimeout(() -> {
            log.debug("Energy SSE timeout for subscription {}", subscriptionId);
            energySubscriptions.remove(subscriptionId);
            completeQuietly(emitter);
        });
        emitter.onError(e -> {
            log.warn("Energy SSE error for subscription {}: {}", subscriptionId, e.getMessage());
            energySubscriptions.remove(subscriptionId);
            completeQuietly(emitter);
        });

        try {
            EnergyOverviewDTO snapshot = overview(1);
            emitter.send(SseEmitter.event().name("INIT").data(snapshot));
        } catch (IOException e) {
            log.warn("Failed to send initial energy SSE event for subscription {}", subscriptionId, e);
            energySubscriptions.remove(subscriptionId);
            completeQuietly(emitter);
        }
        return emitter;
    }

    private void broadcastUpdate() {
        if (energySubscriptions.isEmpty()) {
            return;
        }
        List<String> failed = new ArrayList<>();
        EnergyOverviewDTO overview;
        try {
            overview = overview(1);
        } catch (Exception e) {
            log.error("Failed to build energy overview for SSE broadcast", e);
            return;
        }
        for (Map.Entry<String, SseEmitter> entry : energySubscriptions.entrySet()) {
            try {
                entry.getValue().send(SseEmitter.event().name("ENERGY_UPDATE").data(overview));
            } catch (IOException e) {
                log.debug("Failed to send ENERGY_UPDATE to subscription {}", entry.getKey(), e);
                failed.add(entry.getKey());
            }
        }
        failed.forEach(subscriptionId -> {
            SseEmitter removed = energySubscriptions.remove(subscriptionId);
            if (removed != null) {
                completeQuietly(removed);
            }
        });
    }

    @Scheduled(fixedDelayString = "${app.energy.sse.heartbeat-interval-ms:15000}")
    public void sendHeartbeat() {
        if (energySubscriptions.isEmpty()) {
            return;
        }
        List<String> failed = new ArrayList<>();
        for (Map.Entry<String, SseEmitter> entry : energySubscriptions.entrySet()) {
            try {
                entry.getValue().send(SseEmitter.event().name("HEARTBEAT").data("ping"));
            } catch (IOException e) {
                log.debug("Energy SSE heartbeat failed for subscription {}", entry.getKey(), e);
                failed.add(entry.getKey());
            }
        }
        failed.forEach(subscriptionId -> {
            SseEmitter removed = energySubscriptions.remove(subscriptionId);
            if (removed != null) {
                completeQuietly(removed);
            }
        });
    }

    private void completeQuietly(SseEmitter emitter) {
        try {
            emitter.complete();
        } catch (Exception ignored) {
            // Emitter may already be completed/closed.
        }
    }

    private int normalizeDays(int days) {
        if (days < 1) return 1;
        return Math.min(days, 30);
    }

    private int normalizeBucketMinutes(int bucketMinutes) {
        if (bucketMinutes < 1) return 15;
        return Math.min(bucketMinutes, 60);
    }

    private OffsetDateTime toOffsetUtc(LocalDateTime value) {
        if (value == null) return null;
        return OffsetDateTime.of(value, ZoneOffset.UTC);
    }

    private boolean isFresh(EnergyReading latest, LocalDateTime now) {
        if (latest == null || latest.getRecordedAt() == null || now == null) {
            return false;
        }
        long staleSeconds = liveStaleSeconds > 0 ? liveStaleSeconds : DEFAULT_LIVE_STALE_SECONDS;
        return !latest.getRecordedAt().isBefore(now.minusSeconds(staleSeconds));
    }
}

