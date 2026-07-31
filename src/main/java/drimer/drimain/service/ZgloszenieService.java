package drimer.drimain.service;

import drimer.drimain.api.dto.ZgloszenieCreateRequest;
import drimer.drimain.api.dto.ZgloszenieUpdateRequest;
import drimer.drimain.model.Zgloszenie;
import drimer.drimain.model.enums.ZgloszenieStatus;
import drimer.drimain.repository.ZgloszenieRepository;
import drimer.drimain.util.ZgloszenieStatusMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Service for managing Zgloszenie (Issue) business logic.
 * Handles CRUD operations, validation, and status management.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ZgloszenieService {

    private final ZgloszenieRepository repo;

    /**
     * Create a new Zgloszenie from request DTO.
     * @param req The creation request
     * @return The created Zgloszenie entity
     */
    public Zgloszenie create(ZgloszenieCreateRequest req) {
        log.info("Creating new Zgloszenie: typ={}, priority={}", req.getTyp(), req.getPriorytet());
        
        Zgloszenie z = new Zgloszenie();
        z.setTyp(req.getTyp());
        z.setImie(req.getImie());
        z.setNazwisko(req.getNazwisko());
        z.setTytul(req.getTytul());
        z.setPriorytet(req.getPriorytet());
        
        // Map status safely; default to OPEN
        ZgloszenieStatus st = ZgloszenieStatusMapper.map(req.getStatus());
        z.setStatus(st != null ? st : ZgloszenieStatus.OPEN);
        z.setOpis(req.getOpis());
        z.setDataGodzina(LocalDateTime.now());
        // TODO: photoBase64 -> z.setPhoto(Base64.getDecoder().decode(req.getPhotoBase64()))
        
        Zgloszenie saved = repo.save(z);
        log.info("Zgloszenie created successfully with id={}", saved.getId());
        return saved;
    }

    /**
     * Update an existing Zgloszenie.
     * @param id The Zgloszenie ID
     * @param req The update request
     * @return The updated Zgloszenie entity
     * @throws IllegalArgumentException if Zgloszenie not found
     */
    public Zgloszenie update(Long id, ZgloszenieUpdateRequest req) {
        log.info("Updating Zgloszenie with id={}", id);
        
        Zgloszenie z = repo.findById(id)
                .orElseThrow(() -> {
                    log.warn("Zgloszenie not found with id={}", id);
                    return new IllegalArgumentException("Zgloszenie not found with id: " + id);
                });
        
        if (req.getTyp() != null) {
            z.setTyp(req.getTyp());
        }
        if (req.getStatus() != null) {
            ZgloszenieStatus st = ZgloszenieStatusMapper.map(req.getStatus());
            if (st != null) z.setStatus(st);
        }
        if (req.getOpis() != null) {
            z.setOpis(req.getOpis());
        }
        if (req.getPriorytet() != null) {
            z.setPriorytet(req.getPriorytet());
        }
        if (req.getTytul() != null) {
            z.setTytul(req.getTytul());
        }
        
        Zgloszenie updated = repo.save(z);
        log.info("Zgloszenie updated successfully with id={}", id);
        return updated;
    }

    /**
     * Get Zgloszenie by ID.
     * @param id The Zgloszenie ID
     * @return The Zgloszenie entity
     * @throws IllegalArgumentException if not found
     */
    public Zgloszenie get(Long id) {
        log.debug("Fetching Zgloszenie with id={}", id);
        return repo.findById(id)
                .orElseThrow(() -> {
                    log.warn("Zgloszenie not found with id={}", id);
                    return new IllegalArgumentException("Zgloszenie not found with id: " + id);
                });
    }

    /**
     * Get all Zgłoszenia.
     * @return List of all Zgloszenie entities
     */
    public List<Zgloszenie> all() {
        log.debug("Fetching all Zgłoszenia");
        return repo.findAll();
    }

    /**
     * Delete Zgloszenie by ID.
     * @param id The Zgloszenie ID
     */
    public void delete(Long id) {
        log.info("Deleting Zgloszenie with id={}", id);
        
        if (!repo.existsById(id)) {
            log.warn("Attempted to delete non-existent Zgloszenie with id={}", id);
            throw new IllegalArgumentException("Zgloszenie not found with id: " + id);
        }
        
        repo.deleteById(id);
        log.info("Zgloszenie deleted successfully with id={}", id);
    }
}