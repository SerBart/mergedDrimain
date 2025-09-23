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
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * REST controller for Zgloszenie CRUD.
 * - GET    /api/zgloszenia
 * - POST   /api/zgloszenia
 * - GET    /api/zgloszenia/{id}
 * - PUT    /api/zgloszenia/{id}
 * - DELETE /api/zgloszenia/{id}
 *
 * This version includes explicit @PostMapping and basic error handling so
 * clients get 4xx on validation/permission issues instead of generic 500.
 */
@RestController
@RequestMapping("/api/zgloszenia")
@RequiredArgsConstructor
public class ZgloszenieRestController {

    private final ZgloszenieRepository zgloszenieRepository;
    private final ZgloszenieCommandService commandService;

    /**
     * List with simple filters.
     */
    @GetMapping
    public List<ZgloszenieDTO> list(@RequestParam Optional<String> status,
                                    @RequestParam Optional<String> typ,
                                    @RequestParam Optional<String> q) {
        return zgloszenieRepository.findAll().stream()
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
     */
    @GetMapping("/{id}")
    public ZgloszenieDTO get(@PathVariable Long id) {
        Zgloszenie z = zgloszenieRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Zgłoszenie nie istnieje"));
        return ZgloszenieMapper.toDto(z);
    }

    /**
     * Create new.
     */
    @PostMapping
    public ResponseEntity<ZgloszenieDTO> create(@RequestBody ZgloszenieCreateRequest req,
                                                Authentication authentication) {
        Zgloszenie z = commandService.create(req, authentication);
        return ResponseEntity.status(HttpStatus.CREATED).body(ZgloszenieMapper.toDto(z));
    }

    /**
     * Update existing (ADMIN or BIURO required).
     */
    @PutMapping("/{id}")
    public ZgloszenieDTO update(@PathVariable Long id,
                                @RequestBody ZgloszenieUpdateRequest req,
                                Authentication authentication) {
        if (!hasEditPermissions(authentication)) {
            throw new SecurityException("Brak uprawnień. Wymagana rola ADMIN lub BIURO.");
        }
        Zgloszenie z = commandService.update(id, req, authentication);
        return ZgloszenieMapper.toDto(z);
    }

    /**
     * Delete (ADMIN or BIURO required).
     */
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
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
     * Check if the authenticated user has edit/delete permissions (ADMIN or BIURO role).
     */
    private boolean hasEditPermissions(Authentication authentication) {
        if (authentication == null) return false;
        return authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN")
                        || a.getAuthority().equals("ROLE_BIURO"));
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