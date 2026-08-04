package drimer.drimain.controller;

import drimer.drimain.api.dto.RaportCreateRequest;
import drimer.drimain.api.dto.RaportDTO;
import drimer.drimain.api.dto.RaportUpdateRequest;
import drimer.drimain.api.mapper.RaportMapper;
import drimer.drimain.events.RaportChangedEvent;
import drimer.drimain.model.Raport;
import drimer.drimain.model.User;
import drimer.drimain.model.Zgloszenie;
import drimer.drimain.model.enums.RaportStatus;
import drimer.drimain.model.enums.ZgloszenieStatus;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.OsobaRepository;
import drimer.drimain.repository.RaportRepository;
import drimer.drimain.repository.UserRepository;
import drimer.drimain.repository.ZgloszenieRepository;
import drimer.drimain.repository.spec.RaportSpecifications;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.Base64;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.core.io.ByteArrayResource;

@RestController
@RequestMapping("/api/raporty")
@RequiredArgsConstructor
@Slf4j
public class RaportRestController {

    @Value("${app.attachments.base-path:/tmp/uploads/attachments}")
    private String attachmentsBasePath;

    private static final Set<String> ALLOWED_SORT_FIELDS = Set.of(
            "id", "dataNaprawy", "typNaprawy", "status", "createdBy", "zgloszenieId"
    );

    private final RaportRepository raportRepository;
    private final MaszynaRepository maszynaRepository;
    private final ApplicationEventPublisher publisher;
    private final OsobaRepository osobaRepository;
    private final RaportMapper raportMapper;
    private final ZgloszenieRepository zgloszenieRepository;
    private final UserRepository userRepository;

    @GetMapping
    @Transactional(readOnly = true)
    @PreAuthorize("hasAnyRole('ADMIN','BIURO','USER')")
    public Page<RaportDTO> list(@RequestParam(required = false) String status,
                                @RequestParam(required = false) Long maszynaId,
                                @RequestParam(required = false) LocalDate from,
                                @RequestParam(required = false) LocalDate to,
                                @RequestParam(required = false) String q,
                                @RequestParam(defaultValue = "0") int page,
                                @RequestParam(defaultValue = "25") int size,
                                @RequestParam(defaultValue = "dataNaprawy:desc") String sort,
                                Authentication authentication) {

        // Support both formats: "field:dir,field2:dir2" and legacy "field,desc"
        String[] tokens = sort.split(",");
        java.util.List<Sort.Order> orders = new java.util.ArrayList<>();
        for (int i = 0; i < tokens.length; i++) {
            String token = tokens[i].trim();
            if (token.isEmpty()) continue;
            String field;
            Sort.Direction dir = Sort.Direction.DESC; // default
            if (token.contains(":")) {
                String[] p = token.split(":", 2);
                field = p[0].trim();
                if (p.length > 1 && !p[1].isBlank()) {
                    dir = p[1].equalsIgnoreCase("asc") ? Sort.Direction.ASC : Sort.Direction.DESC;
                }
            } else {
                field = token;
                // legacy format: next token equals asc/desc
                if (i + 1 < tokens.length) {
                    String next = tokens[i + 1].trim();
                    if ("asc".equalsIgnoreCase(next) || "desc".equalsIgnoreCase(next)) {
                        dir = "asc".equalsIgnoreCase(next) ? Sort.Direction.ASC : Sort.Direction.DESC;
                        i++; // consume next
                    }
                }
            }
            if (!field.isBlank() && ALLOWED_SORT_FIELDS.contains(field)) {
                orders.add(new Sort.Order(dir, field));
            } else if (!field.isBlank()) {
                log.warn("Ignoring unsupported raport sort field: {}", field);
            }
        }
        if (orders.isEmpty()) {
            orders.add(new Sort.Order(Sort.Direction.DESC, "dataNaprawy"));
        }
        Sort sortObj = Sort.by(orders);

        Pageable pageable = PageRequest.of(page, size, sortObj);

        RaportStatus statusEnum = null;
        if (status != null && !status.isBlank()) {
            try { statusEnum = RaportStatus.valueOf(status); } catch (Exception ignored) {}
        }

        Specification<Raport> spec =
                Specification.where(RaportSpecifications.hasStatus(statusEnum))
                        .and(RaportSpecifications.hasMaszynaId(maszynaId))
                        .and(RaportSpecifications.dateFrom(from))
                        .and(RaportSpecifications.dateTo(to))
                        .and(RaportSpecifications.fullText(q));

        // Filter by user's department if not admin and not "Utrzymanie Ruchu"
        if (authentication != null) {
            boolean isAdmin = authentication.getAuthorities().stream()
                    .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
            if (!isAdmin) {
                User user = userRepository.findByUsernameFetchDzial(authentication.getName())
                        .orElse(null);
                if (user == null) {
                    log.warn("Authenticated user not found in database: {}", authentication.getName());
                }
                var userDzial = user != null ? user.getDzial() : null;
                // Utrzymanie Ruchu ma dostęp do wszystkich raportów oprócz działu Technologie
                boolean isUtrzymanieRuchu = userDzial != null
                        && "Utrzymanie Ruchu".equalsIgnoreCase(userDzial.getNazwa());
                if (isUtrzymanieRuchu) {
                    // Utrzymanie Ruchu widzi wszystkie raporty OPRÓCZ działu Technologie
                    spec = spec.and(RaportSpecifications.excludeDzialByName("Technologie"));
                } else if (userDzial != null) {
                    spec = spec.and(RaportSpecifications.hasDzial(userDzial.getId()));
                }
            }
        }

        Page<Raport> pageData = raportRepository.findAll(spec, pageable);
        return pageData.map(raportMapper::toDto);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','BIURO','USER')")
    public RaportDTO get(@PathVariable Long id) {
        Raport r = raportRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Raport not found"));
        return raportMapper.toDto(r);
    }

    // Create report: require module AND role (ADMIN or BIURO)
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','BIURO')")
    public RaportDTO create(@RequestBody RaportCreateRequest req,
                           @AuthenticationPrincipal UserDetails userDetails) {
        Raport r = new Raport();
        r.setTypNaprawy(req.getTypNaprawy());
        r.setOpis(req.getOpis());
        
        // NOTE: Set audit field - who created the report
        if (userDetails != null) {
            r.setCreatedBy(userDetails.getUsername());
            log.info("Report created by user: {}", userDetails.getUsername());
        }
        
        raportMapper.applyCreateDefaults(r, req);
        r.setDataNaprawy(req.getDataNaprawy());
        try {
            if (req.getCzasOd() != null) r.setCzasOd(raportMapper.parseTime(req.getCzasOd()));
            if (req.getCzasDo() != null) r.setCzasDo(raportMapper.parseTime(req.getCzasDo()));
        } catch (IllegalArgumentException ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, ex.getMessage());
        }
        if (req.getMaszynaId() != null)
            r.setMaszyna(maszynaRepository.findById(req.getMaszynaId()).orElse(null));
        if (req.getOsobaId() != null)
            r.setOsoba(osobaRepository.findById(req.getOsobaId()).orElse(null));
        if (req.getPartUsages() != null) {
            raportMapper.applyPartUsages(r, req.getPartUsages());
        }
        raportRepository.save(r);
        publisher.publishEvent(new RaportChangedEvent(this, raportMapper.toDto(r), "CREATED"));

        return raportMapper.toDto(r);
    }

    // Update report: require module AND role (ADMIN or BIURO)
    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','BIURO','USER')")
    public RaportDTO update(@PathVariable Long id, @RequestBody RaportUpdateRequest req,
                           @AuthenticationPrincipal UserDetails userDetails) {
        Raport r = raportRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Raport not found"));
        if (req.getStatus() != null) {
            try { r.setStatus(RaportStatus.valueOf(req.getStatus())); } catch (Exception ignored) {}
        }
        raportMapper.updateEntity(r, req);
        raportRepository.save(r);
        publisher.publishEvent(new RaportChangedEvent(this, raportMapper.toDto(r), "UPDATED"));

        if (userDetails != null) {
            log.info("Report {} updated by user: {}", id, userDetails.getUsername());
        }
        return raportMapper.toDto(r);
    }

    // Delete: require ADMIN + module
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasRole('ADMIN') and @moduleGuard.has('Raporty')")
    public void delete(@PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails) {
        raportRepository.deleteById(id);
        if (userDetails != null) {
            log.info("Report {} deleted by user: {}", id, userDetails.getUsername());
        }
    }

    // Backfill: utwórz raporty dla ZAKOŃCZONYCH (DONE) zgłoszeń bez raportu
    @PostMapping("/backfill-from-zgloszenia")
    @PreAuthorize("hasAnyRole('ADMIN','BIURO') and @moduleGuard.has('Raporty')")
    public int backfillFromZgloszenia() {
        int created = 0;
        var doneList = zgloszenieRepository.findAll().stream()
                .filter(z -> z.getStatus() == ZgloszenieStatus.DONE)
                .toList();
        for (Zgloszenie z : doneList) {
            if (z.getId() == null) continue;
            if (raportRepository.findByZgloszenieId(z.getId()).isPresent()) continue;
            Raport r = new Raport();
            r.setZgloszenieId(z.getId());
            r.setMaszyna(z.getMaszyna());
            r.setTypNaprawy(z.getTyp());
            r.setOpis(z.getOpis());
            r.setStatus(drimer.drimain.model.enums.RaportStatus.ZAKONCZONE);
            var data = z.getCompletedAt() != null ? z.getCompletedAt().toLocalDate() : java.time.LocalDate.now();
            r.setDataNaprawy(data);
            if (z.getAcceptedAt() != null) r.setCzasOd(z.getAcceptedAt().toLocalTime());
            if (z.getCompletedAt() != null) r.setCzasDo(z.getCompletedAt().toLocalTime());
            if (z.getAutor() != null) r.setCreatedBy(z.getAutor().getUsername());
            raportRepository.save(r);
            created++;
        }
        log.info("Backfill raportów zakończony. Utworzono: {}", created);
        return created;
    }

    @PostMapping("/{id}/zdjecia")
    @PreAuthorize("hasAnyRole('ADMIN','BIURO','USER')")
    @ResponseStatus(HttpStatus.OK)
    public List<String> uploadZdjecia(@PathVariable Long id, @RequestParam("zdjecia") List<MultipartFile> zdjecia) {
        Raport raport = raportRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Raport not found"));

        List<String> uploadedPaths = new java.util.ArrayList<>();

        for (MultipartFile file : zdjecia) {
            try {
                if (!file.isEmpty()) {
                    StoredPhoto storedPhoto = saveFile(file);
                    raport.getZdjecia().add(storedPhoto.inlineValue());
                    uploadedPaths.add(storedPhoto.filename());
                    log.info("Uploaded photo for raport {}: {}", id, storedPhoto.filename());
                }
            } catch (Exception e) {
                log.error("Failed to upload photo for raport {}: {}", id, e.getMessage(), e);
                throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to upload photo: " + e.getMessage());
            }
        }

        raportRepository.save(raport);
        return uploadedPaths;
    }

    @GetMapping("/{id}/zdjecia/{filename}")
    @PreAuthorize("hasAnyRole('ADMIN','BIURO','USER')")
    public ResponseEntity<Resource> downloadZdjecie(@PathVariable Long id, @PathVariable String filename) {
        Raport raport = raportRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Raport not found"));

        String normalizedFilename = java.net.URLDecoder.decode(filename, java.nio.charset.StandardCharsets.UTF_8);

        // Security: verify the file is actually associated with this raport
        boolean fileExists = raport.getZdjecia().stream()
                .anyMatch(path -> {
                    String normalizedPath = path == null ? "" : path.replace('\\', '/');
                    String stored = normalizedPath.substring(normalizedPath.lastIndexOf('/') + 1);
                    return stored.equals(normalizedFilename) || normalizedPath.endsWith("/" + normalizedFilename) || normalizedPath.contains(normalizedFilename);
                });

        if (!fileExists) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Photo not found for this raport");
        }

        Path filePath = Paths.get(attachmentsBasePath, normalizedFilename).normalize();

        // New persistent mode: inline photo content stored in DB row raport_zdjecia.
        String inlinePrefix = "inline:" + normalizedFilename + ":";
        var inline = raport.getZdjecia().stream()
                .filter(path -> path != null && path.startsWith(inlinePrefix))
                .findFirst();

        if (inline.isPresent()) {
            String inlinePayload = inline.get().substring(inlinePrefix.length());
            int marker = inlinePayload.indexOf(";base64,");
            String contentType = marker > 0 ? inlinePayload.substring(0, marker) : "image/jpeg";
            String encoded = marker > 0 ? inlinePayload.substring(marker + 8) : inlinePayload;
            try {
                byte[] decoded = Base64.getDecoder().decode(encoded);
                Resource resource = new ByteArrayResource(decoded);
                return ResponseEntity.ok()
                        .header("Content-Type", contentType)
                        .body(resource);
            } catch (IllegalArgumentException e) {
                throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Invalid inline photo data");
            }
        }

        // Backward compatibility: old entries are still disk-based.
        if (Files.exists(filePath)) {
            try {
                Resource resource = new FileSystemResource(filePath);
                String contentType = Files.probeContentType(filePath);
                if (contentType == null) {
                    contentType = "image/jpeg"; // default
                }
                return ResponseEntity.ok()
                        .header("Content-Type", contentType)
                        .body(resource);
            } catch (IllegalArgumentException e) {
                throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Invalid photo path");
            } catch (IOException e) {
                log.warn("Failed to read photo from disk, trying DB fallback. Path={}", filePath, e);
            }
        }

        throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Photo not found");
    }

    @DeleteMapping("/{id}/zdjecia/{filename}")
    @PreAuthorize("hasAnyRole('ADMIN','BIURO','USER')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteZdjecie(@PathVariable Long id, @PathVariable String filename) {
        Raport raport = raportRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Raport not found"));

        // Remove from set
        raport.getZdjecia().removeIf(path -> path.endsWith(filename) || path.contains(filename));
        raportRepository.save(raport);

        // Delete file from disk
        Path filePath = Paths.get(attachmentsBasePath, filename);
        try {
            Files.deleteIfExists(filePath);
            log.info("Deleted photo for raport {}: {}", id, filename);
        } catch (IOException e) {
            log.warn("Failed to delete photo file: {}", filePath, e);
            // Don't throw - already removed from DB
        }
    }

    private StoredPhoto saveFile(MultipartFile file) {
        if (file.isEmpty()) {
            throw new IllegalArgumentException("File is empty");
        }

        String originalFilename = file.getOriginalFilename();
        if (originalFilename == null || originalFilename.isEmpty()) {
            throw new IllegalArgumentException("Invalid filename");
        }

        // Generate unique filename
        String fileExtension = getFileExtension(originalFilename);
        String storedFilename = UUID.randomUUID() + fileExtension;

        try {
            byte[] bytes = file.getBytes();
            String contentType = file.getContentType();
            if (contentType == null || contentType.isBlank()) {
                contentType = "image/jpeg";
            }
            String encoded = Base64.getEncoder().encodeToString(bytes);
            String inlineValue = "inline:" + storedFilename + ":" + contentType + ";base64," + encoded;
            return new StoredPhoto(storedFilename, contentType, inlineValue);
        } catch (IOException e) {
            log.error("Failed to save file: {}", originalFilename, e);
            throw new RuntimeException("Failed to save photo: " + e.getMessage(), e);
        }
    }

    private record StoredPhoto(String filename, String contentType, String inlineValue) {}

    private String getFileExtension(String filename) {
        if (filename == null || filename.isEmpty()) {
            return "";
        }
        int lastDotIndex = filename.lastIndexOf('.');
        return lastDotIndex > 0 ? filename.substring(lastDotIndex).toLowerCase() : "";
    }
}
