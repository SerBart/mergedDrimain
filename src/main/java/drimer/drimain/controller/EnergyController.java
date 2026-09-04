package drimer.drimain.controller;

import drimer.drimain.api.dto.EnergyHistoryPointDTO;
import drimer.drimain.api.dto.EnergyMachineSummaryDTO;
import drimer.drimain.api.dto.EnergyOverviewDTO;
import drimer.drimain.api.dto.EnergyReadingIngestRequest;
import drimer.drimain.model.EnergyReading;
import drimer.drimain.service.EnergyService;
import drimer.drimain.service.EnergyScopeType;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.hibernate.LazyInitializationException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import org.springframework.format.annotation.DateTimeFormat;

import java.time.LocalDateTime;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.List;

@RestController
@RequestMapping("/api/energia")
@RequiredArgsConstructor
public class EnergyController {

    private final EnergyService energyService;

    @Value("${app.energy.ingest-key:}")
    private String ingestKey;

    @PostMapping("/readings")
    @ResponseStatus(HttpStatus.CREATED)
    public EnergyMachineSummaryDTO ingest(
            @RequestHeader(value = "X-API-KEY", required = false) String apiKey,
            @Valid @RequestBody EnergyReadingIngestRequest req) {
        if (!isValidIngestKey(apiKey)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Invalid energy ingest key");
        }
        EnergyReading saved = energyService.ingest(req);
        return toMachineSummary(saved);
    }

    @GetMapping("/overview")
    @PreAuthorize("isAuthenticated()")
    public EnergyOverviewDTO overview(
            @RequestParam(name = "scope", defaultValue = "TOTAL") String scope,
            @RequestParam(name = "dzialId", required = false) Long dzialId,
            @RequestParam(name = "maszynaId", required = false) Long maszynaId,
            @RequestParam(name = "days", defaultValue = "1") int days) {
        return energyService.overview(EnergyScopeType.from(scope), dzialId, maszynaId, days);
    }

    @GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    @PreAuthorize("isAuthenticated()")
    public SseEmitter stream(
            @RequestParam(name = "scope", defaultValue = "TOTAL") String scope,
            @RequestParam(name = "dzialId", required = false) Long dzialId,
            @RequestParam(name = "maszynaId", required = false) Long maszynaId) {
        return energyService.subscribeToUpdates(scope, dzialId, maszynaId);
    }

    @GetMapping("/machines/latest")
    @PreAuthorize("isAuthenticated()")
    public List<EnergyMachineSummaryDTO> latestMachines() {
        return energyService.latestMachines();
    }

    @GetMapping("/history")
    @PreAuthorize("isAuthenticated()")
    public List<EnergyHistoryPointDTO> history(
            @RequestParam(name = "scope", defaultValue = "TOTAL") String scope,
            @RequestParam(name = "dzialId", required = false) Long dzialId,
            @RequestParam(name = "maszynaId", required = false) Long maszynaId,
            @RequestParam(name = "days", defaultValue = "7") int days,
            @RequestParam(name = "bucketMinutes", defaultValue = "5") int bucketMinutes) {
        return energyService.history(EnergyScopeType.from(scope), dzialId, maszynaId, days, bucketMinutes);
    }

    @GetMapping(value = "/history/export", produces = "text/csv")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<String> exportHistory(
            @RequestParam(name = "scope", defaultValue = "TOTAL") String scope,
            @RequestParam(name = "dzialId", required = false) Long dzialId,
            @RequestParam(name = "maszynaId", required = false) Long maszynaId,
            @RequestParam(name = "days", defaultValue = "7") int days,
            @RequestParam(name = "bucketMinutes", defaultValue = "5") int bucketMinutes) {
        EnergyScopeType scopeType = EnergyScopeType.from(scope);
        List<EnergyHistoryPointDTO> points = energyService.history(scopeType, dzialId, maszynaId, days, bucketMinutes);
        String csv = buildHistoryCsv(points);

        String filename = "energia-history-" + scopeType.name().toLowerCase(java.util.Locale.ROOT) + "-" + days + "d.csv";
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(new MediaType("text", "csv", StandardCharsets.UTF_8));
        headers.set(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"");

        return ResponseEntity.ok()
                .headers(headers)
                .body(csv);
    }

    @GetMapping("/machines/{maszynaId}/history")
    @PreAuthorize("isAuthenticated()")
    public List<EnergyHistoryPointDTO> history(
            @PathVariable Long maszynaId,
            @RequestParam(name = "days", defaultValue = "7") int days,
            @RequestParam(name = "bucketMinutes", defaultValue = "5") int bucketMinutes) {
        return energyService.history(EnergyScopeType.MASZYNA, null, maszynaId, days, bucketMinutes);
    }

    @DeleteMapping("/admin/machines/{maszynaId}/readings")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, Object>> deleteMachineReadings(
            @PathVariable Long maszynaId,
            @RequestParam(name = "from", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime from,
            @RequestParam(name = "to", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime to) {
        int deleted = energyService.deleteReadingsForMachine(maszynaId, from, to);
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("maszynaId", maszynaId);
        body.put("deletedCount", deleted);
        body.put("from", from);
        body.put("to", to);
        return ResponseEntity.ok(body);
    }

    private boolean isValidIngestKey(String provided) {
        if (ingestKey == null || ingestKey.isBlank()) {
            return false;
        }
        if (provided == null || provided.isBlank()) {
            return false;
        }
        return constantTimeEquals(ingestKey.trim(), provided.trim());
    }

    private boolean constantTimeEquals(String a, String b) {
        byte[] aa = a.getBytes(StandardCharsets.UTF_8);
        byte[] bb = b.getBytes(StandardCharsets.UTF_8);
        if (aa.length != bb.length) return false;
        try {
            return MessageDigest.isEqual(aa, bb);
        } finally {
            java.util.Arrays.fill(aa, (byte) 0);
            java.util.Arrays.fill(bb, (byte) 0);
        }
    }

    private EnergyMachineSummaryDTO toMachineSummary(EnergyReading saved) {
        EnergyMachineSummaryDTO dto = new EnergyMachineSummaryDTO();
        dto.setMaszynaId(saved.getMaszyna() != null ? saved.getMaszyna().getId() : null);
        dto.setMaszynaNazwa(saved.getMaszyna() != null ? saved.getMaszyna().getNazwa() : null);
        try {
            if (saved.getMaszyna() != null && saved.getMaszyna().getDzial() != null) {
                dto.setDzialId(saved.getMaszyna().getDzial().getId());
                dto.setDzialNazwa(saved.getMaszyna().getDzial().getNazwa());
            }
        } catch (LazyInitializationException | IllegalStateException ex) {
            // Ingest response should still succeed even if lazy relation cannot initialize here.
            dto.setDzialId(null);
            dto.setDzialNazwa(null);
        }
        dto.setDeviceId(saved.getDeviceId());
        dto.setLastRecordedAt(saved.getRecordedAt() != null ? java.time.OffsetDateTime.of(saved.getRecordedAt(), java.time.ZoneOffset.UTC) : null);
        dto.setPowerKw(saved.getPowerKw());
        dto.setEnergyKwhTotal(saved.getEnergyKwhTotal());
        dto.setTodayEnergyKwh(java.math.BigDecimal.ZERO);
        dto.setReadingsCount(1L);
        return dto;
    }

    private String buildHistoryCsv(List<EnergyHistoryPointDTO> points) {
        StringBuilder sb = new StringBuilder();
        sb.append("czas;deviceId;mocKw;energiaKwhTotal;napiecieV;pradA\n");
        for (EnergyHistoryPointDTO point : points) {
            sb.append(csvEscape(point.getRecordedAt() == null ? "" : point.getRecordedAt().toString())).append(';')
                    .append(csvEscape(point.getDeviceId())).append(';')
                    .append(csvEscape(point.getPowerKw() == null ? "" : point.getPowerKw().toPlainString())).append(';')
                    .append(csvEscape(point.getEnergyKwhTotal() == null ? "" : point.getEnergyKwhTotal().toPlainString())).append(';')
                    .append(csvEscape(point.getVoltageV() == null ? "" : point.getVoltageV().toPlainString())).append(';')
                    .append(csvEscape(point.getCurrentA() == null ? "" : point.getCurrentA().toPlainString()))
                    .append('\n');
        }
        return sb.toString();
    }

    private String csvEscape(String value) {
        if (value == null) {
            return "";
        }
        String escaped = value.replace("\"", "\"\"");
        if (escaped.indexOf(';') >= 0 || escaped.indexOf('"') >= 0 || escaped.indexOf('\n') >= 0 || escaped.indexOf('\r') >= 0) {
            return '"' + escaped + '"';
        }
        return escaped;
    }
}


