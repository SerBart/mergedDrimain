package drimer.drimain.controller;

import drimer.drimain.api.dto.HarmonogramCreateRequest;
import drimer.drimain.api.dto.HarmonogramDTO;
import drimer.drimain.api.dto.HarmonogramUpdateRequest;
import drimer.drimain.api.dto.SimpleDzialDTO;
import drimer.drimain.api.dto.SimpleMaszynaDTO;
import drimer.drimain.api.dto.SimpleOsobaDTO;
import drimer.drimain.api.dto.SimpleSekcjaDTO;
import drimer.drimain.model.Harmonogram;
import drimer.drimain.model.Maszyna;
import drimer.drimain.model.NotificationType;
import drimer.drimain.model.Osoba;
import drimer.drimain.model.enums.HarmonogramOkres;
import drimer.drimain.model.enums.StatusHarmonogramu;
import drimer.drimain.repository.DzialRepository;
import drimer.drimain.repository.HarmonogramRepository;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.OsobaRepository;
import drimer.drimain.service.NotificationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/harmonogramy")
@RequiredArgsConstructor
@Slf4j
public class HarmonogramRestController {

    private static final LocalDate DEFAULT_PLAN_END_DATE = LocalDate.of(2027, 12, 31);
    private static final Set<String> ALLOWED_INLINE_CONTENT_TYPES = Set.of(
            "image/jpeg", "image/png", "image/gif", "image/webp", "application/pdf"
    );

    private final HarmonogramRepository harmonogramRepository;
    private final MaszynaRepository maszynaRepository;
    private final OsobaRepository osobaRepository;
    private final DzialRepository dzialRepository;
    private final NotificationService notificationService;

    @GetMapping
    @Transactional(readOnly = true)
    public List<HarmonogramDTO> list(@RequestParam Optional<Integer> year, @RequestParam Optional<Integer> month) {
        List<Harmonogram> entities;
        if (year.isPresent()) {
            int y = year.get();
            LocalDate start;
            LocalDate end;
            if (month.isPresent()) {
                int m = month.get();
                start = LocalDate.of(y, m, 1);
                end = start.withDayOfMonth(start.lengthOfMonth());
            } else {
                start = LocalDate.of(y, 1, 1);
                end = LocalDate.of(y, 12, 31);
            }
            entities = harmonogramRepository.findByDataBetweenWithJoins(start, end);
        } else {
            entities = harmonogramRepository.findAllWithJoins();
        }
        return entities.stream().map(this::toDto).collect(Collectors.toList());
    }

    @GetMapping("/{id}")
    @Transactional(readOnly = true)
    public HarmonogramDTO get(@PathVariable Long id) {
        Harmonogram h = harmonogramRepository.findByIdWithJoins(id).stream()
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Harmonogram not found"));
        return toDto(h);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public HarmonogramDTO create(@Valid @RequestBody HarmonogramCreateRequest req) {
        Maszyna maszyna = req.getMaszynaId() != null
                ? maszynaRepository.findById(req.getMaszynaId())
                .orElseThrow(() -> new IllegalArgumentException("Maszyna not found"))
                : null;
        Osoba osoba = req.getOsobaId() != null
                ? osobaRepository.findById(req.getOsobaId())
                .orElseThrow(() -> new IllegalArgumentException("Osoba not found"))
                : null;
        var dzial = req.getDzialId() != null
                ? dzialRepository.findById(req.getDzialId())
                .orElseThrow(() -> new IllegalArgumentException("Dzial not found"))
                : null;

        LocalDate planEndDate = req.getPlanEndDate() != null ? req.getPlanEndDate() : DEFAULT_PLAN_END_DATE;
        if (planEndDate.isBefore(req.getData())) {
            throw new IllegalArgumentException("Data konca planu nie moze byc wczesniejsza niz data pierwszego przegladu");
        }

        Harmonogram first = new Harmonogram();
        first.setData(req.getData());
        first.setOpis(req.getOpis());
        first.setDurationMinutes(req.getDurationMinutes());
        first.setMaszyna(maszyna);
        first.setOsoba(osoba);
        first.setDzial(dzial);
        first.setStatus(req.getStatus() != null ? req.getStatus() : StatusHarmonogramu.PLANOWANE);
        first.setFrequency(req.getFrequency());
        first.setPlanEndDate(planEndDate);
        first.setSeriesId(req.getFrequency() != null ? UUID.randomUUID().toString() : null);

        List<Harmonogram> toSave = new ArrayList<>();
        toSave.add(first);
        if (req.getFrequency() != null) {
            LocalDate nextPlannedDate = first.getData();
            while (true) {
                nextPlannedDate = nextDate(nextPlannedDate, req.getFrequency());
                if (nextPlannedDate.isAfter(planEndDate)) {
                    break;
                }
                toSave.add(cloneForSeries(first, nextPlannedDate, StatusHarmonogramu.PLANOWANE));
            }
        }

        harmonogramRepository.saveAll(toSave);

        try {
            notificationService.createModuleNotification(
                    "Harmonogramy",
                    NotificationType.NEW_HARMONOGRAM,
                    "Nowy harmonogram",
                    first.getOpis() != null ? first.getOpis() : "",
                    "/harmonogramy/" + first.getId()
            );
        } catch (Exception ex) {
            log.warn("Nie udalo sie utworzyc powiadomienia dla harmonogramu", ex);
        }

        return toDto(first);
    }

    @PutMapping("/{id}")
    @Transactional
    public HarmonogramDTO update(@PathVariable Long id, @Valid @RequestBody HarmonogramUpdateRequest req) {
        Harmonogram h = harmonogramRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Harmonogram not found"));

        boolean applyToSeriesFuture = Boolean.TRUE.equals(req.getApplyToSeriesFuture());
        LocalDate originalDate = h.getData();

        if (req.getData() != null) h.setData(req.getData());
        if (req.getOpis() != null) h.setOpis(req.getOpis());
        if (req.getDurationMinutes() != null) h.setDurationMinutes(req.getDurationMinutes());
        if (req.getMaszynaId() != null) {
            h.setMaszyna(maszynaRepository.findById(req.getMaszynaId())
                    .orElseThrow(() -> new IllegalArgumentException("Maszyna not found")));
        }
        if (req.getOsobaId() != null) {
            h.setOsoba(osobaRepository.findById(req.getOsobaId())
                    .orElseThrow(() -> new IllegalArgumentException("Osoba not found")));
        }
        if (req.getStatus() != null) h.setStatus(req.getStatus());
        if (req.getDzialId() != null) {
            h.setDzial(dzialRepository.findById(req.getDzialId())
                    .orElseThrow(() -> new IllegalArgumentException("Dzial not found")));
        }
        if (req.getFrequency() != null) h.setFrequency(req.getFrequency());
        if (req.getPlanEndDate() != null) h.setPlanEndDate(req.getPlanEndDate());

        if (h.getPlanEndDate() == null) {
            h.setPlanEndDate(DEFAULT_PLAN_END_DATE);
        }
        if (h.getData() != null && h.getPlanEndDate().isBefore(h.getData())) {
            throw new IllegalArgumentException("Data konca planu nie moze byc wczesniejsza niz data przegladu");
        }

        harmonogramRepository.save(h);

        if (applyToSeriesFuture && h.getSeriesId() != null && !h.getSeriesId().isBlank() && h.getFrequency() != null) {
            List<Harmonogram> futurePlanned = harmonogramRepository
                    .findBySeriesIdAndDataGreaterThanEqualAndStatus(h.getSeriesId(), originalDate, StatusHarmonogramu.PLANOWANE)
                    .stream()
                    .filter(item -> !item.getId().equals(h.getId()))
                    .collect(Collectors.toList());

            if (!futurePlanned.isEmpty()) {
                harmonogramRepository.deleteAll(futurePlanned);
            }

            List<Harmonogram> regenerated = new ArrayList<>();
            LocalDate next = h.getData();
            while (true) {
                next = nextDate(next, h.getFrequency());
                if (next.isAfter(h.getPlanEndDate())) {
                    break;
                }
                regenerated.add(cloneForSeries(h, next, StatusHarmonogramu.PLANOWANE));
            }
            if (!regenerated.isEmpty()) {
                harmonogramRepository.saveAll(regenerated);
            }
        }

        return toDto(h);
    }

    @PostMapping("/{id}/complete")
    @Transactional
    public LinkedHashMap<String, Object> complete(@PathVariable Long id) {
        Harmonogram h = harmonogramRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Harmonogram not found"));

        h.setStatus(StatusHarmonogramu.ZAKONCZONE);
        harmonogramRepository.save(h);

        boolean planFinished = false;
        if (h.getSeriesId() != null && !h.getSeriesId().isBlank() && h.getData() != null) {
            long futureCount = harmonogramRepository.countBySeriesIdAndDataAfter(h.getSeriesId(), h.getData());
            planFinished = futureCount == 0;
        }

        LinkedHashMap<String, Object> result = new LinkedHashMap<>();
        result.put("id", h.getId());
        result.put("status", h.getStatus());
        result.put("planFinished", planFinished);
        if (planFinished) {
            result.put("message", "Plan przegladow zakonczony");
        }
        return result;
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        harmonogramRepository.deleteById(id);
    }

    @PostMapping("/{id}/zalaczniki")
    @Transactional
    @PreAuthorize("hasAnyRole('ADMIN','BIURO','USER')")
    public List<String> uploadZalaczniki(@PathVariable Long id, @RequestParam("zalaczniki") List<MultipartFile> zalaczniki) {
        Harmonogram h = harmonogramRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Harmonogram not found"));

        List<String> uploaded = new ArrayList<>();
        for (MultipartFile file : zalaczniki) {
            if (file == null || file.isEmpty()) {
                continue;
            }
            StoredAttachment stored = saveFile(file);
            h.getZalaczniki().add(stored.inlineValue);
            uploaded.add(stored.filename);
        }

        harmonogramRepository.save(h);
        return uploaded;
    }

    @GetMapping("/{id}/zalaczniki/{filename}")
    @Transactional(readOnly = true)
    @PreAuthorize("hasAnyRole('ADMIN','BIURO','USER')")
    public ResponseEntity<Resource> downloadZalacznik(@PathVariable Long id, @PathVariable String filename) {
        Harmonogram h = harmonogramRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Harmonogram not found"));

        String normalizedFilename = java.net.URLDecoder.decode(filename, StandardCharsets.UTF_8);
        String inlinePrefix = "inline:" + normalizedFilename + ":";

        Optional<String> inline = h.getZalaczniki().stream()
                .filter(path -> path != null && path.startsWith(inlinePrefix))
                .findFirst();

        if (inline.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Attachment not found");
        }

        String inlinePayload = inline.get().substring(inlinePrefix.length());
        int marker = inlinePayload.indexOf(";base64,");
        String contentType = marker > 0 ? inlinePayload.substring(0, marker) : "application/octet-stream";
        String encoded = marker > 0 ? inlinePayload.substring(marker + 8) : inlinePayload;

        try {
            byte[] decoded = Base64.getDecoder().decode(encoded);
            return ResponseEntity.ok()
                    .header("Content-Type", contentType)
                    .body(new ByteArrayResource(decoded));
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Invalid inline attachment data");
        }
    }

    @DeleteMapping("/{id}/zalaczniki/{filename}")
    @Transactional
    @PreAuthorize("hasAnyRole('ADMIN','BIURO','USER')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteZalacznik(@PathVariable Long id, @PathVariable String filename) {
        Harmonogram h = harmonogramRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Harmonogram not found"));

        String normalizedFilename = java.net.URLDecoder.decode(filename, StandardCharsets.UTF_8);
        h.getZalaczniki().removeIf(path -> path != null && (path.contains(normalizedFilename) || path.endsWith(normalizedFilename)));
        harmonogramRepository.save(h);
    }

    private HarmonogramDTO toDto(Harmonogram h) {
        HarmonogramDTO dto = new HarmonogramDTO();
        dto.setId(h.getId());
        dto.setData(h.getData());
        dto.setOpis(h.getOpis());
        dto.setStatus(h.getStatus());
        dto.setDurationMinutes(h.getDurationMinutes());
        dto.setFrequency(h.getFrequency());
        dto.setSeriesId(h.getSeriesId());
        dto.setPlanEndDate(h.getPlanEndDate());

        dto.setZalaczniki(normalizeAttachments(h.getZalaczniki()));

        if (h.getDzial() != null) {
            SimpleDzialDTO dzDto = new SimpleDzialDTO();
            dzDto.setId(h.getDzial().getId());
            dzDto.setNazwa(h.getDzial().getNazwa());
            dto.setDzial(dzDto);
        }

        if (h.getMaszyna() != null) {
            SimpleMaszynaDTO maszynaDto = new SimpleMaszynaDTO();
            maszynaDto.setId(h.getMaszyna().getId());
            maszynaDto.setNazwa(h.getMaszyna().getNazwa());

            if (h.getMaszyna().getDzial() != null) {
                SimpleDzialDTO d = new SimpleDzialDTO();
                d.setId(h.getMaszyna().getDzial().getId());
                d.setNazwa(h.getMaszyna().getDzial().getNazwa());
                maszynaDto.setDzial(d);
            }

            if (h.getMaszyna().getSekcja() != null) {
                SimpleSekcjaDTO s = new SimpleSekcjaDTO();
                s.setId(h.getMaszyna().getSekcja().getId());
                s.setNazwa(h.getMaszyna().getSekcja().getNazwa());
                maszynaDto.setSekcja(s);
            }

            dto.setMaszyna(maszynaDto);
        }

        if (h.getOsoba() != null) {
            SimpleOsobaDTO osobaDto = new SimpleOsobaDTO();
            osobaDto.setId(h.getOsoba().getId());
            osobaDto.setImieNazwisko(h.getOsoba().getImieNazwisko());
            dto.setOsoba(osobaDto);
        }

        return dto;
    }

    private List<String> normalizeAttachments(Set<String> attachments) {
        if (attachments == null) {
            return List.of();
        }
        return attachments.stream()
                .map(path -> {
                    if (path == null) {
                        return null;
                    }
                    String value = path.trim();
                    if (value.startsWith("inline:")) {
                        int first = value.indexOf(':');
                        int second = value.indexOf(':', first + 1);
                        if (second > first + 1) {
                            return value.substring(first + 1, second);
                        }
                    }
                    return value;
                })
                .filter(v -> v != null && !v.isBlank())
                .collect(Collectors.toList());
    }

    private Harmonogram cloneForSeries(Harmonogram source, LocalDate date, StatusHarmonogramu status) {
        Harmonogram clone = new Harmonogram();
        clone.setData(date);
        clone.setOpis(source.getOpis());
        clone.setMaszyna(source.getMaszyna());
        clone.setOsoba(source.getOsoba());
        clone.setDzial(source.getDzial());
        clone.setDurationMinutes(source.getDurationMinutes());
        clone.setFrequency(source.getFrequency());
        clone.setSeriesId(source.getSeriesId());
        clone.setPlanEndDate(source.getPlanEndDate());
        clone.setStatus(status);
        return clone;
    }

    private LocalDate nextDate(LocalDate current, HarmonogramOkres frequency) {
        switch (frequency) {
            case TYGODNIOWY:
                return current.plusWeeks(1);
            case MIESIECZNY:
                return current.plusMonths(1);
            case KWARTALNY:
                return current.plusMonths(3);
            case POLROCZNY:
                return current.plusMonths(6);
            case ROCZNY:
                return current.plusYears(1);
            case DWULETNI:
                return current.plusYears(2);
            case PIECIOLETNI:
                return current.plusYears(5);
            default:
                throw new IllegalArgumentException("Unsupported frequency: " + frequency);
        }
    }

    private StoredAttachment saveFile(MultipartFile file) {
        if (file.isEmpty()) {
            throw new IllegalArgumentException("File is empty");
        }

        String originalFilename = file.getOriginalFilename();
        if (originalFilename == null || originalFilename.isEmpty()) {
            throw new IllegalArgumentException("Invalid filename");
        }

        String fileExtension = getFileExtension(originalFilename);
        String storedFilename = UUID.randomUUID() + fileExtension;

        try {
            byte[] bytes = file.getBytes();
            String contentType = resolveAndValidateContentType(file.getContentType(), fileExtension, bytes);
            String encoded = Base64.getEncoder().encodeToString(bytes);
            String inlineValue = "inline:" + storedFilename + ":" + contentType + ";base64," + encoded;
            return new StoredAttachment(storedFilename, contentType, inlineValue);
        } catch (java.io.IOException e) {
            throw new RuntimeException("Failed to save attachment: " + e.getMessage(), e);
        }
    }

    private String resolveAndValidateContentType(String requestedContentType, String extension, byte[] bytes) {
        String normalizedType = requestedContentType == null ? "" : requestedContentType.trim().toLowerCase();
        String typeBySignature = detectContentType(bytes);

        if (!normalizedType.isBlank() && ALLOWED_INLINE_CONTENT_TYPES.contains(normalizedType)) {
            if (!typeBySignature.isBlank() && !normalizedType.equals(typeBySignature)) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "File content does not match declared content type");
            }
            return normalizedType;
        }

        if (!typeBySignature.isBlank()) {
            return typeBySignature;
        }

        if (".pdf".equalsIgnoreCase(extension)) {
            return "application/pdf";
        }

        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Only image and PDF files are allowed");
    }

    private String detectContentType(byte[] bytes) {
        if (bytes == null || bytes.length < 4) {
            return "";
        }

        if (startsWith(bytes, new byte[]{0x25, 0x50, 0x44, 0x46})) return "application/pdf";
        if (startsWith(bytes, new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF})) return "image/jpeg";
        if (startsWith(bytes, new byte[]{(byte) 0x89, 0x50, 0x4E, 0x47})) return "image/png";
        if (startsWith(bytes, "GIF8".getBytes(StandardCharsets.US_ASCII))) return "image/gif";

        if (bytes.length >= 12
                && startsWith(bytes, "RIFF".getBytes(StandardCharsets.US_ASCII))
                && Arrays.equals(Arrays.copyOfRange(bytes, 8, 12), "WEBP".getBytes(StandardCharsets.US_ASCII))) {
            return "image/webp";
        }

        return "";
    }

    private boolean startsWith(byte[] bytes, byte[] prefix) {
        if (bytes.length < prefix.length) {
            return false;
        }
        for (int i = 0; i < prefix.length; i++) {
            if (bytes[i] != prefix[i]) {
                return false;
            }
        }
        return true;
    }

    private String getFileExtension(String filename) {
        if (filename == null || filename.isEmpty()) {
            return "";
        }
        int lastDotIndex = filename.lastIndexOf('.');
        return lastDotIndex > 0 ? filename.substring(lastDotIndex).toLowerCase() : "";
    }

    private static final class StoredAttachment {
        private final String filename;
        private final String contentType;
        private final String inlineValue;

        private StoredAttachment(String filename, String contentType, String inlineValue) {
            this.filename = filename;
            this.contentType = contentType;
            this.inlineValue = inlineValue;
        }
    }
}
