package drimer.drimain.controller;

import drimer.drimain.api.dto.*;
import drimer.drimain.api.mapper.ZgloszenieMapper;
import drimer.drimain.model.Zgloszenie;
import drimer.drimain.model.enums.ZgloszenieStatus;
import drimer.drimain.repository.ZgloszenieRepository;
import drimer.drimain.service.ZgloszenieCommandService;
import drimer.drimain.util.ZgloszenieStatusMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/zgloszenia")
@RequiredArgsConstructor
public class ZgloszenieRestController {

    private final ZgloszenieRepository zgloszenieRepository;
    private final ZgloszenieCommandService commandService;

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

    @GetMapping("/{id}")
    public ZgloszenieDTO get(@PathVariable Long id) {
        Zgloszenie z = zgloszenieRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Zgloszenie not found"));
        return ZgloszenieMapper.toDto(z);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ZgloszenieDTO create(@RequestBody ZgloszenieCreateRequest req, Authentication authentication) {
        Zgloszenie z = commandService.create(req, authentication);
        return ZgloszenieMapper.toDto(z);
    }

    @PutMapping("/{id}")
    public ZgloszenieDTO update(@PathVariable Long id, @RequestBody ZgloszenieUpdateRequest req, 
                                Authentication authentication) {
        // Check if user has edit permissions (ADMIN or BIURO roles)
        if (!hasEditPermissions(authentication)) {
            throw new SecurityException("Access denied. Admin or Biuro role required.");
        }
        
        Zgloszenie z = commandService.update(id, req, authentication);
        return ZgloszenieMapper.toDto(z);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id, Authentication authentication) {
        // Check if user has delete permissions (ADMIN or BIURO roles)
        if (!hasEditPermissions(authentication)) {
            throw new SecurityException("Access denied. Admin or Biuro role required.");
        }
        commandService.delete(id, authentication);
    }
    
    /**
     * Check if the authenticated user has edit/delete permissions (ADMIN or BIURO role)
     */
    private boolean hasEditPermissions(Authentication authentication) {
        if (authentication == null) return false;
        return authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN") || 
                              a.getAuthority().equals("ROLE_BIURO"));
    }
}