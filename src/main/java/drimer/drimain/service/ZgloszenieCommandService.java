package drimer.drimain.service;

import drimer.drimain.api.dto.ZgloszenieCreateRequest;
import drimer.drimain.api.dto.ZgloszenieUpdateRequest;
import drimer.drimain.events.EventType;
import drimer.drimain.events.ZgloszenieDomainEvent;
import drimer.drimain.model.Dzial;
import drimer.drimain.model.User;
import drimer.drimain.model.Zgloszenie;
import drimer.drimain.model.enums.ZgloszenieStatus;
import drimer.drimain.repository.DzialRepository;
import drimer.drimain.repository.UserRepository;
import drimer.drimain.repository.ZgloszenieRepository;
import drimer.drimain.util.ZgloszenieStatusMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

@Service
@RequiredArgsConstructor
@Transactional
@Slf4j
public class ZgloszenieCommandService {

    private final ZgloszenieRepository zgloszenieRepository;
    private final DzialRepository dzialRepository;
    private final UserRepository userRepository;
    private final ApplicationEventPublisher eventPublisher;

    public Zgloszenie create(ZgloszenieCreateRequest req, Authentication authentication) {
        Zgloszenie z = new Zgloszenie();
        
        // Set basic fields
        if (req.getTyp() != null) z.setTyp(req.getTyp());
        if (req.getImie() != null) z.setImie(req.getImie());
        if (req.getNazwisko() != null) z.setNazwisko(req.getNazwisko());
        if (req.getTytul() != null) z.setTytul(req.getTytul());
        if (req.getOpis() != null) z.setOpis(req.getOpis());
        if (req.getDataGodzina() != null) z.setDataGodzina(req.getDataGodzina());
        
        // Set status
        if (req.getStatus() != null) {
            ZgloszenieStatus status = ZgloszenieStatusMapper.map(req.getStatus());
            if (status != null) z.setStatus(status);
        }

        // Set relations
        if (req.getDzialId() != null) {
            Dzial dzial = dzialRepository.findById(req.getDzialId())
                    .orElseThrow(() -> new IllegalArgumentException("Dzial not found"));
            z.setDzial(dzial);
        }

        // Set author from authentication
        if (authentication != null && authentication.getName() != null) {
            User user = userRepository.findByUsername(authentication.getName()).orElse(null);
            if (user != null) {
                z.setAutor(user);
            }
        }

        // Validate
        z.validate();

        // Save
        Zgloszenie saved = zgloszenieRepository.save(z);

        // Publish creation event
        eventPublisher.publishEvent(new ZgloszenieDomainEvent(
                this,
                EventType.CREATED,
                saved.getId()
        ));

        log.debug("Created zgloszenie {} with ID {}", saved.getTytul(), saved.getId());
        return saved;
    }

    public Zgloszenie update(Long id, ZgloszenieUpdateRequest req, Authentication authentication) {
        Zgloszenie z = zgloszenieRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Zgloszenie not found"));

        // Track changed fields
        List<String> changedFields = new ArrayList<>();

        // Update basic fields and track changes
        if (req.getTyp() != null && !Objects.equals(z.getTyp(), req.getTyp())) {
            z.setTyp(req.getTyp());
            changedFields.add("typ");
        }
        if (req.getImie() != null && !Objects.equals(z.getImie(), req.getImie())) {
            z.setImie(req.getImie());
            changedFields.add("imie");
        }
        if (req.getNazwisko() != null && !Objects.equals(z.getNazwisko(), req.getNazwisko())) {
            z.setNazwisko(req.getNazwisko());
            changedFields.add("nazwisko");
        }
        if (req.getTytul() != null && !Objects.equals(z.getTytul(), req.getTytul())) {
            z.setTytul(req.getTytul());
            changedFields.add("tytul");
        }
        if (req.getOpis() != null && !Objects.equals(z.getOpis(), req.getOpis())) {
            z.setOpis(req.getOpis());
            changedFields.add("opis");
        }

        // Update status and track changes
        if (req.getStatus() != null) {
            ZgloszenieStatus newStatus = ZgloszenieStatusMapper.map(req.getStatus());
            if (newStatus != null && !Objects.equals(z.getStatus(), newStatus)) {
                z.setStatus(newStatus);
                changedFields.add("status");
            }
        }

        // Handle dzial relation
        if (req.getDzialId() != null) {
            Dzial dzial = dzialRepository.findById(req.getDzialId())
                    .orElseThrow(() -> new IllegalArgumentException("Dzial not found"));
            
            if (!Objects.equals(z.getDzial() == null ? null : z.getDzial().getId(), req.getDzialId())) {
                z.setDzial(dzial);
                changedFields.add("dzialId");
            }
        }

        // Validate if any changes were made
        if (!changedFields.isEmpty()) {
            z.validate();
        }

        // Save
        Zgloszenie saved = zgloszenieRepository.save(z);

        // Publish update event with changed fields
        if (!changedFields.isEmpty()) {
            eventPublisher.publishEvent(new ZgloszenieDomainEvent(
                    this,
                    EventType.UPDATED,
                    saved.getId(),
                    changedFields
            ));
            
            log.debug("Updated zgloszenie {} with changes: {}", saved.getId(), changedFields);
        }

        return saved;
    }

    public void delete(Long id, Authentication authentication) {
        Zgloszenie z = zgloszenieRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Zgloszenie not found"));

        // Delete the entity
        zgloszenieRepository.delete(z);

        // Publish deletion event
        eventPublisher.publishEvent(new ZgloszenieDomainEvent(
                this,
                EventType.DELETED,
                id
        ));

        log.debug("Deleted zgloszenie with ID {}", id);
    }
}