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
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class EnergyService {

    private final EnergyReadingRepository energyReadingRepository;
    private final MaszynaRepository maszynaRepository;
    private final Map<String, SseEmitter> energySubscriptions = new ConcurrentHashMap<>();

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
        
        // Broadcast nowy odczyt do wszystkich nasłuchujących
        broadcastUpdate(saved);
        
        return saved;
    }

    @Transactional(readOnly = true)
    public EnergyOverviewDTO overview(EnergyScopeType scope, Long dzialId, Long maszynaId, int days) {
        int normalizedDays = normalizeDays(days);
        LocalDate today = LocalDate.now();
        LocalDate startDate = today.minusDays(normalizedDays - 1L);
        LocalDateTime start = startDate.atStartOfDay();
        LocalDateTime endExclusive = today.plusDays(1).atStartOfDay();
        LocalDateTime activeThreshold = LocalDateTime.now().minusMinutes(30);

        List<Maszyna> machinesInScope = resolveMachines(scope, dzialId, maszynaId);
        Map<Long, Maszyna> machinesById = machinesInScope.stream()
                .filter(m -> m.getId() != null)
                .collect(Collectors.toMap(Maszyna::getId, m -> m, (a, b) -> a, LinkedHashMap::new));

        if (machinesById.isEmpty()) {
            EnergyOverviewDTO empty = new EnergyOverviewDTO();
            empty.setScopeType(scope.name());
            empty.setScopeLabel(resolveScopeLabel(scope, null, dzialId, maszynaId));
            empty.setZakresDni(normalizedDays);
            empty.setBucketMinutes(15);
            empty.setGeneratedAt(OffsetDateTime.now(ZoneOffset.UTC));
            empty.setTotalMachines(0);
            empty.setMachines(List.of());
            return empty;
        }

        List<EnergyReading> readings = energyReadingRepository.findByRecordedAtBetweenOrderByRecordedAtAsc(start, endExclusive);
        Map<Long, List<EnergyReading>> grouped = new LinkedHashMap<>();
        for (EnergyReading reading : readings) {
            if (reading.getMaszyna() == null || reading.getMaszyna().getId() == null) {
                continue;
            }
            if (!machinesById.containsKey(reading.getMaszyna().getId())) {
                continue;
            }
            grouped.computeIfAbsent(reading.getMaszyna().getId(), k -> new ArrayList<>()).add(reading);
        }

        List<EnergyMachineSummaryDTO> machines = new ArrayList<>();
        BigDecimal totalPowerKw = BigDecimal.ZERO;
        BigDecimal todayEnergyKwh = BigDecimal.ZERO;
        long activeMachines = 0;

        for (Maszyna maszyna : machinesInScope) {
            List<EnergyReading> machineReadings = grouped.getOrDefault(maszyna.getId(), List.of());
            EnergyReading latest = machineReadings.stream()
                    .filter(r -> r.getRecordedAt() != null)
                    .max(Comparator.comparing(EnergyReading::getRecordedAt))
                    .orElse(null);
            List<EnergyReading> todayReadings = machineReadings.stream()
                    .filter(r -> r.getRecordedAt() != null && !r.getRecordedAt().isBefore(start))
                    .toList();
            BigDecimal deltaToday = EnergyAggregationUtils.calculateEnergyDelta(todayReadings);

            EnergyMachineSummaryDTO dto = buildMachineSummary(maszyna, latest, machineReadings, deltaToday);
            machines.add(dto);

            totalPowerKw = totalPowerKw.add(dto.getPowerKw() != null ? dto.getPowerKw() : BigDecimal.ZERO);
            todayEnergyKwh = todayEnergyKwh.add(deltaToday);
            if (latest != null && latest.getRecordedAt() != null && !latest.getRecordedAt().isBefore(activeThreshold)) {
                activeMachines++;
            }
        }

        machines.sort(Comparator.comparing(
                EnergyMachineSummaryDTO::getMaszynaNazwa,
                Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER)
        ));

        EnergyOverviewDTO overview = new EnergyOverviewDTO();
        overview.setScopeType(scope.name());
        overview.setScopeLabel(resolveScopeLabel(scope, machines, dzialId, maszynaId));
        overview.setZakresDni(normalizedDays);
        overview.setBucketMinutes(15);
        overview.setGeneratedAt(OffsetDateTime.now(ZoneOffset.UTC));
        overview.setTotalPowerKw(totalPowerKw.max(BigDecimal.ZERO));
        overview.setTodayEnergyKwh(todayEnergyKwh.max(BigDecimal.ZERO));
        overview.setActiveMachines(activeMachines);
        overview.setTotalMachines(machinesInScope.size());
        overview.setMachines(machines);
        return overview;
    }

    @Transactional(readOnly = true)
    public List<EnergyHistoryPointDTO> history(EnergyScopeType scope, Long dzialId, Long maszynaId, int days, int bucketMinutes) {
        int normalizedDays = normalizeDays(days);
        int normalizedBucketMinutes = normalizeBucketMinutes(bucketMinutes);
        LocalDate today = LocalDate.now();
        LocalDate startDate = today.minusDays(normalizedDays - 1L);
        LocalDateTime start = startDate.atStartOfDay();
        LocalDateTime endExclusive = today.plusDays(1).atStartOfDay();

        List<Maszyna> machinesInScope = resolveMachines(scope, dzialId, maszynaId);
        if (machinesInScope.isEmpty()) {
            return List.of();
        }

        Set<Long> machineIds = machinesInScope.stream()
                .map(Maszyna::getId)
                .filter(id -> id != null)
                .collect(Collectors.toSet());
        if (machineIds.isEmpty()) {
            return List.of();
        }

        List<EnergyReading> readings = energyReadingRepository.findByRecordedAtBetweenOrderByRecordedAtAsc(start, endExclusive)
                .stream()
                .filter(r -> r.getMaszyna() != null && r.getMaszyna().getId() != null && machineIds.contains(r.getMaszyna().getId()))
                .toList();
        return EnergyAggregationUtils.aggregateHistory(readings, normalizedBucketMinutes);
    }

    @Transactional(readOnly = true)
    public List<EnergyMachineSummaryDTO> latestMachines() {
        return overview(EnergyScopeType.TOTAL, null, null, 1).getMachines();
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

    private List<Maszyna> resolveMachines(EnergyScopeType scope, Long dzialId, Long maszynaId) {
        EnergyScopeType effectiveScope = scope == null ? EnergyScopeType.TOTAL : scope;
        return switch (effectiveScope) {
            case DZIAL -> {
                if (dzialId == null) {
                    throw new IllegalArgumentException("DzialId jest wymagane dla zakresu DZIAL");
                }
                yield sortMachines(maszynaRepository.findByDzial_Id(dzialId));
            }
            case MASZYNA -> {
                if (maszynaId == null) {
                    throw new IllegalArgumentException("MaszynaId jest wymagane dla zakresu MASZYNA");
                }
                yield maszynaRepository.findById(maszynaId)
                        .map(List::of)
                        .orElseThrow(() -> new IllegalArgumentException("Maszyna not found"));
            }
            case TOTAL -> sortMachines(maszynaRepository.findAll());
        };
    }

    private List<Maszyna> sortMachines(List<Maszyna> machines) {
        return machines.stream()
                .sorted(Comparator.comparing(this::machineNameForSort, Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER)))
                .toList();
    }

    private String machineNameForSort(Maszyna maszyna) {
        if (maszyna == null) {
            return null;
        }
        if (maszyna.getNazwa() != null && !maszyna.getNazwa().isBlank()) {
            return maszyna.getNazwa();
        }
        return "Maszyna #" + maszyna.getId();
    }

    private EnergyMachineSummaryDTO buildMachineSummary(Maszyna maszyna, EnergyReading latest, List<EnergyReading> machineReadings, BigDecimal todayDelta) {
        EnergyMachineSummaryDTO dto = new EnergyMachineSummaryDTO();
        dto.setMaszynaId(maszyna.getId());
        dto.setMaszynaNazwa(machineNameForSort(maszyna));
        if (maszyna.getDzial() != null) {
            dto.setDzialId(maszyna.getDzial().getId());
            dto.setDzialNazwa(maszyna.getDzial().getNazwa());
        }
        if (latest != null) {
            dto.setDeviceId(latest.getDeviceId());
            dto.setLastRecordedAt(toOffsetUtc(latest.getRecordedAt()));
            dto.setPowerKw(latest.getPowerKw() != null ? latest.getPowerKw() : BigDecimal.ZERO);
            dto.setEnergyKwhTotal(latest.getEnergyKwhTotal());
        } else {
            dto.setPowerKw(BigDecimal.ZERO);
            dto.setEnergyKwhTotal(null);
        }
        dto.setTodayEnergyKwh(todayDelta != null ? todayDelta : BigDecimal.ZERO);
        dto.setReadingsCount(machineReadings != null ? machineReadings.size() : 0);
        return dto;
    }

    private String resolveScopeLabel(EnergyScopeType scope, List<EnergyMachineSummaryDTO> machines, Long dzialId, Long maszynaId) {
        EnergyScopeType effectiveScope = scope == null ? EnergyScopeType.TOTAL : scope;
        return switch (effectiveScope) {
            case TOTAL -> "Całość zakładu";
            case DZIAL -> {
                String dzialName = machines == null ? null : machines.stream()
                        .map(EnergyMachineSummaryDTO::getDzialNazwa)
                        .filter(name -> name != null && !name.isBlank())
                        .findFirst()
                        .orElse(null);
                yield dzialName != null ? "Dział: " + dzialName : "Dział #" + dzialId;
            }
            case MASZYNA -> {
                String machineName = machines == null ? null : machines.stream()
                        .map(EnergyMachineSummaryDTO::getMaszynaNazwa)
                        .filter(name -> name != null && !name.isBlank())
                        .findFirst()
                        .orElse(null);
                yield machineName != null ? "Maszyna: " + machineName : "Maszyna #" + maszynaId;
            }
        };
    }

    public SseEmitter subscribeToUpdates(String scope, Long dzialId, Long maszynaId) {
        EnergyScopeType scopeType = EnergyScopeType.from(scope);
        SseEmitter emitter = new SseEmitter(300_000L); // 5 min timeout
        
        String subscriptionId = UUID.randomUUID().toString();
        String subscriptionKey = buildSubscriptionKey(subscriptionId, scopeType, dzialId, maszynaId);
        
        energySubscriptions.put(subscriptionKey, emitter);
        
        emitter.onCompletion(() -> {
            energySubscriptions.remove(subscriptionKey);
            log.debug("SSE subscription {} completed", subscriptionKey);
        });
        emitter.onTimeout(() -> {
            energySubscriptions.remove(subscriptionKey);
            log.debug("SSE subscription {} timed out", subscriptionKey);
        });
        emitter.onError(e -> {
            energySubscriptions.remove(subscriptionKey);
            log.debug("SSE subscription {} error", subscriptionKey, e);
        });
        
        try {
            // Wyślij initial event z aktualnym stanem
            EnergyOverviewDTO overview = overview(scopeType, dzialId, maszynaId, 1);
            emitter.send(SseEmitter.event()
                    .name("INIT")
                    .data(overview));
        } catch (IOException e) {
            log.warn("Failed to send initial event to subscription {}", subscriptionKey, e);
            energySubscriptions.remove(subscriptionKey);
        }
        
        log.debug("SSE subscription {} created. Active subscriptions: {}", subscriptionKey, energySubscriptions.size());
        return emitter;
    }

    private void broadcastUpdate(EnergyReading reading) {
        if (reading == null || reading.getMaszyna() == null) {
            return;
        }
        
        Long maszynaId = reading.getMaszyna().getId();
        
        List<String> failedSubscriptions = new ArrayList<>();
        
        energySubscriptions.entrySet().parallelStream().forEach(entry -> {
            String subscriptionKey = entry.getKey();
            SseEmitter emitter = entry.getValue();
            
            try {
                // Sprawdzamy czy ten subscription interesuje się tą maszyną
                if (shouldBroadcastToSubscription(subscriptionKey, maszynaId, reading)) {
                    EnergyOverviewDTO overview = extractScopeFromKey(subscriptionKey);
                    if (overview != null) {
                        emitter.send(SseEmitter.event()
                                .name("ENERGY_UPDATE")
                                .data(overview));
                    }
                }
            } catch (IOException e) {
                log.debug("Failed to send update to subscription {}", subscriptionKey);
                synchronized (failedSubscriptions) {
                    failedSubscriptions.add(subscriptionKey);
                }
            }
        });
        
        failedSubscriptions.forEach(energySubscriptions::remove);
    }

    private boolean shouldBroadcastToSubscription(String subscriptionKey, Long maszynaId, EnergyReading reading) {
        // Format: "id|scope|dzialId|maszynaId"
        String[] parts = subscriptionKey.split("\\|");
        if (parts.length < 2) return false;
        
        String scopeStr = parts[1];
        EnergyScopeType scope = EnergyScopeType.from(scopeStr);
        
        switch (scope) {
            case TOTAL:
                return true; // Broadcast do wszystkich TOTAL subscribers
            case MASZYNA:
                if (parts.length >= 4) {
                    try {
                        Long subscribedMaszynaId = Long.parseLong(parts[3]);
                        return subscribedMaszynaId.equals(maszynaId);
                    } catch (NumberFormatException e) {
                        return false;
                    }
                }
                return false;
            case DZIAL:
                if (parts.length >= 3 && reading.getMaszyna().getDzial() != null) {
                    try {
                        Long subscribedDzialId = Long.parseLong(parts[2]);
                        return subscribedDzialId.equals(reading.getMaszyna().getDzial().getId());
                    } catch (NumberFormatException e) {
                        return false;
                    }
                }
                return false;
            default:
                return false;
        }
    }

    private EnergyOverviewDTO extractScopeFromKey(String subscriptionKey) {
        String[] parts = subscriptionKey.split("\\|");
        if (parts.length < 2) return null;
        
        String scopeStr = parts[1];
        EnergyScopeType scope = EnergyScopeType.from(scopeStr);
        
        Long dzialId = parts.length > 2 ? tryParseLong(parts[2]) : null;
        Long maszynaId = parts.length > 3 ? tryParseLong(parts[3]) : null;
        
        try {
            return overview(scope, dzialId, maszynaId, 1);
        } catch (Exception e) {
            log.debug("Failed to generate overview for subscription key {}", subscriptionKey, e);
            return null;
        }
    }

    private Long tryParseLong(String value) {
        try {
            return Long.parseLong(value);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private String buildSubscriptionKey(String subscriptionId, EnergyScopeType scope, Long dzialId, Long maszynaId) {
        return String.format("%s|%s|%s|%s", 
            subscriptionId, 
            scope.name(), 
            dzialId != null ? dzialId : "",
            maszynaId != null ? maszynaId : "");
    }

    public int getActiveSubscriptionCount() {
        return energySubscriptions.size();
    }
}
