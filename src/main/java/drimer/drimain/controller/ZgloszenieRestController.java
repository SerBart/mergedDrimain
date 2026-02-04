package drimer.drimain.controller;

import drimer.drimain.api.dto.ZgloszenieCreateRequest;
import drimer.drimain.api.dto.ZgloszenieDTO;
import drimer.drimain.api.dto.ZgloszenieUpdateRequest;
import drimer.drimain.api.mapper.ZgloszenieMapper;
import drimer.drimain.model.Zgloszenie;
import drimer.drimain.model.enums.ZgloszenieStatus;
import drimer.drimain.repository.ZgloszenieRepository;
import drimer.drimain.service.ZgloszenieCommandService;
import drimer.drimain.util.ZgloszenieStatusMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

// New imports
import drimer.drimain.repository.UserRepository;
import drimer.drimain.model.User;
import drimer.drimain.service.NotificationService;
import drimer.drimain.model.NotificationType;

/**
 * REST controller for Zgloszenie CRUD.
 * - GET    /api/zgloszenia
 * - POST   /api/zgloszenia
 * - GET    /api/zgloszenia/{id}
 * - PUT    /api/zgloszenia/{id}
 * - DELETE /api/zgloszenia/{id}
 *
 * Zabezpieczenia przed LazyInitializationException:
 * - @Transactional(readOnly = true) na metodach GET (list/get)
 * - repozytorium fetchuje relacje poprzez @EntityGraph (autor, dzial)
 */
@RestController
@RequestMapping("/api/zgloszenia")
@RequiredArgsConstructor
@Slf4j
public class ZgloszenieRestController {

    private final ZgloszenieRepository zgloszenieRepository;
    private final ZgloszenieCommandService commandService;
    // New: to resolve current user's department
    private final UserRepository userRepository;
    // New: notification service
    private final NotificationService notificationService;

    /**
     * List with simple filters.
     * Trzyma transakcję otwartą na czas mapowania do DTO, aby Lazy nie wywalił.
     * Dodatkowo ogranicza widoczność do działu użytkownika (poza ADMIN).
     */
    @GetMapping
    @Transactional(readOnly = true)
    @PreAuthorize("@moduleGuard.has('Zgloszenia')")
    public List<ZgloszenieDTO> list(@RequestParam Optional<String> status,
                                    @RequestParam Optional<String> typ,
                                    @RequestParam Optional<String> q,
                                    Authentication authentication) {

        List<Zgloszenie> all = zgloszenieRepository.findAll();

        // If not admin, restrict to user's department if assigned
        if (authentication != null) {
            boolean isAdmin = authentication.getAuthorities().stream()
                    .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
            if (!isAdmin) {
                User u = userRepository.findByUsername(authentication.getName()).orElse(null);
                // Utrzymanie Ruchu ma dostęp do wszystkich zgłoszeń oprócz działu Technologie
                boolean isUtrzymanieRuchu = u != null && u.getDzial() != null
                        && "Utrzymanie Ruchu".equalsIgnoreCase(u.getDzial().getNazwa());
                if (isUtrzymanieRuchu) {
                    // Utrzymanie Ruchu widzi wszystkie zgłoszenia OPRÓCZ działu Technologie
                    all = all.stream()
                            .filter(z -> z.getDzial() == null || !"Technologie".equalsIgnoreCase(z.getDzial().getNazwa()))
                            .collect(Collectors.toList());
                } else {
                    Long dzialId = (u != null && u.getDzial() != null) ? u.getDzial().getId() : null;
                    if (dzialId != null) {
                        all = all.stream().filter(z -> z.getDzial() != null && dzialId.equals(z.getDzial().getId()))
                                .collect(Collectors.toList());
                    } else {
                        // Brak przypisanego działu -> nie pokazuj nic
                        all = List.of();
                    }
                }
            }
        } else {
            // Not authenticated -> empty
            all = List.of();
        }

        return all.stream()
                .filter(z -> status
                        .map(s -> {
                            ZgloszenieStatus ms = ZgloszenieStatusMapper.map(s);
                            return ms != null && ms == z.getStatus();
                        })
                        .orElse(true))
                .filter(z -> typ
                        .map(t -> z.getTyp() != null && z.getTyp().equalsIgnoreCase(t))
                        .orElse(true))
                .filter(z -> q
                        .map(query -> {
                            String qq = query.toLowerCase();
                            return (z.getOpis() != null && z.getOpis().toLowerCase().contains(qq)) ||
                                    (z.getTyp() != null && z.getTyp().toLowerCase().contains(qq)) ||
                                    (z.getImie() != null && z.getImie().toLowerCase().contains(qq)) ||
                                    (z.getNazwisko() != null && z.getNazwisko().toLowerCase().contains(qq)) ||
                                    (z.getTytul() != null && z.getTytul().toLowerCase().contains(qq));
                        })
                        .orElse(true))
                .map(ZgloszenieMapper::toDto)
                .collect(Collectors.toList());
    }

    /**
     * Get by id.
     * Trzyma transakcję, a repo fetchuje relacje autor/dzial.
     */
    @GetMapping("/{id}")
    @Transactional(readOnly = true)
    @PreAuthorize("@moduleGuard.has('Zgloszenia')")
    public ZgloszenieDTO get(@PathVariable Long id) {
        Zgloszenie z = zgloszenieRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Zgłoszenie nie istnieje"));
        return ZgloszenieMapper.toDto(z);
    }

    /**
     * Create new.
     */
    @PostMapping
    @PreAuthorize("@moduleGuard.has('Zgloszenia')")
    public ResponseEntity<ZgloszenieDTO> create(@RequestBody ZgloszenieCreateRequest req,
                                                Authentication authentication) {
        Zgloszenie z = commandService.create(req, authentication);

        // Create module notification for users who have access to "Zgloszenia" (except excluded modules handled in service)
        try {
            String title = "Nowe zgłoszenie";
            String message = z.getTytul() != null ? z.getTytul() : (z.getOpis() != null ? z.getOpis() : "");
            String link = "/zgloszenia/" + z.getId();
            notificationService.createModuleNotification("Zgloszenia", NotificationType.NEW_ZGLOSZENIE, title, message, link);
        } catch (Exception ex) {
            // Nie przerywamy tworzenia zgloszenia, logowanie opcjonalne
        }

        return ResponseEntity.status(HttpStatus.CREATED).body(ZgloszenieMapper.toDto(z));
    }

    /**
     * Update existing.
     * Dozwolone dla:
     * - ADMIN / BIURO - mogą edytować wszystkie zgłoszenia
     * - Użytkownicy z dostępem do modułu 'Zgloszenia' - mogą edytować zgłoszenia w swoim dziale
     *
     * WAŻNE: Gdy zgłoszenie zostanie zmienione na status DONE (zamknięte),
     * system automatycznie utworzy raport na podstawie tego zgłoszenia.
     * Raport trafi do listy raportów z statusem NOWY.
     */
    @PutMapping("/{id}")
    @Transactional
    @PreAuthorize("@moduleGuard.has('Zgloszenia')")
    public ZgloszenieDTO update(@PathVariable Long id,
                                @RequestBody ZgloszenieUpdateRequest req,
                                Authentication authentication) {
        Zgloszenie existing = zgloszenieRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Zgłoszenie nie istnieje"));

        if (!canEditZgloszenie(authentication, existing)) {
            throw new SecurityException("Brak uprawnień do edycji tego zgłoszenia.");
        }
        Zgloszenie z = commandService.update(id, req, authentication);
        return ZgloszenieMapper.toDto(z);
    }

    /**
     * Delete (ADMIN or BIURO required).
     */
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("@moduleGuard.has('Zgloszenia')")
    public void delete(@PathVariable Long id, Authentication authentication) {
        if (!hasEditPermissions(authentication)) {
            throw new SecurityException("Brak uprawnień. Wymagana rola ADMIN lub BIURO.");
        }
        commandService.delete(id, authentication);
    }

    /**
     * Map UI status names to enum if someone sends raw UI values here.
     */
    private ZgloszenieStatus mapStatus(String raw) {
        return ZgloszenieStatusMapper.map(raw);
    }

    /**
     * Check if the authenticated user has global edit/delete permissions (ADMIN or BIURO role).
     */
    private boolean hasEditPermissions(Authentication authentication) {
        if (authentication == null) return false;
        return authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN")
                        || a.getAuthority().equals("ROLE_BIURO"));
    }

    /**
     * Check if the authenticated user can edit the given Zgloszenie.
     * Returns true if:
     * - User has ADMIN or BIURO role (can edit all)
     * - User belongs to the same department as the Zgloszenie (or its maszyna)
     * - User belongs to "Utrzymanie Ruchu" department (can edit all except Technologie)
     */
    private boolean canEditZgloszenie(Authentication authentication, Zgloszenie zgloszenie) {
        if (authentication == null) {
            log.warn("canEditZgloszenie: authentication is null");
            return false;
        }

        // ADMIN or BIURO can edit all
        if (hasEditPermissions(authentication)) {
            log.debug("canEditZgloszenie: user {} has ADMIN/BIURO permissions", authentication.getName());
            return true;
        }

        // Check if user belongs to the same department or is from Utrzymanie Ruchu
        User user = userRepository.findByUsername(authentication.getName()).orElse(null);
        if (user == null || user.getDzial() == null) {
            log.warn("canEditZgloszenie: user {} not found or has no dzial", authentication.getName());
            return false;
        }

        String userDzialName = user.getDzial().getNazwa();

        // Determine the effective dzial of the zgloszenie (from zgloszenie itself or from maszyna)
        String zgloszenieDzialName = null;
        Long zgloszenieDzialId = null;

        if (zgloszenie.getDzial() != null) {
            zgloszenieDzialName = zgloszenie.getDzial().getNazwa();
            zgloszenieDzialId = zgloszenie.getDzial().getId();
        } else if (zgloszenie.getMaszyna() != null && zgloszenie.getMaszyna().getDzial() != null) {
            // Fallback to maszyna's dzial if zgloszenie has no direct dzial
            zgloszenieDzialName = zgloszenie.getMaszyna().getDzial().getNazwa();
            zgloszenieDzialId = zgloszenie.getMaszyna().getDzial().getId();
        }

        log.debug("canEditZgloszenie: user {} from dzial '{}', zgloszenie dzial '{}'",
                  authentication.getName(), userDzialName, zgloszenieDzialName);

        // Utrzymanie Ruchu can edit all zgłoszenia except those from Technologie
        if ("Utrzymanie Ruchu".equalsIgnoreCase(userDzialName)) {
            if (zgloszenieDzialName != null && "Technologie".equalsIgnoreCase(zgloszenieDzialName)) {
                log.warn("canEditZgloszenie: Utrzymanie Ruchu user cannot edit Technologie zgloszenie");
                return false;
            }
            return true;
        }

        // Technologie users can edit zgłoszenia from Technologie department
        if ("Technologie".equalsIgnoreCase(userDzialName)) {
            if (zgloszenieDzialName != null && "Technologie".equalsIgnoreCase(zgloszenieDzialName)) {
                log.debug("canEditZgloszenie: Technologie user can edit Technologie zgloszenie");
                return true;
            }
        }

        // Other users can edit zgłoszenia from their own department
        if (zgloszenieDzialId != null && user.getDzial().getId().equals(zgloszenieDzialId)) {
            log.debug("canEditZgloszenie: user can edit - same department");
            return true;
        }

        log.warn("canEditZgloszenie: user {} cannot edit zgloszenie {} - different departments",
                 authentication.getName(), zgloszenie.getId());
        return false;
    }

    // ---------- Basic error handling to avoid generic 500 ----------

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<?> handleIllegalArgument(IllegalArgumentException ex) {
        return ResponseEntity.badRequest().body(new ErrorResponse(ex.getMessage()));
    }

    @ExceptionHandler(SecurityException.class)
    public ResponseEntity<?> handleSecurity(SecurityException ex) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(new ErrorResponse(ex.getMessage()));
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<?> handleMethodNotSupported(HttpRequestMethodNotSupportedException ex) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).body(new ErrorResponse(ex.getMessage()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<?> handleOther(Exception ex) {
        String msg = ex.getMessage() == null ? "Wewnętrzny błąd serwera" : ex.getMessage();
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(new ErrorResponse(msg));
    }

    public static class ErrorResponse {
        public final String message;
        public ErrorResponse(String message) { this.message = message; }
    }
}
