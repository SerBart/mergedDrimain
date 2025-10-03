package drimer.drimain.events;

import drimer.drimain.model.Raport;
import drimer.drimain.model.Zgloszenie;
import drimer.drimain.model.enums.RaportStatus;
import drimer.drimain.model.enums.ZgloszenieStatus;
import drimer.drimain.repository.RaportRepository;
import drimer.drimain.repository.ZgloszenieRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

@Component
@RequiredArgsConstructor
@Slf4j
public class ZgloszenieToRaportListener {

    private final ZgloszenieRepository zgloszenieRepository;
    private final RaportRepository raportRepository;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional
    public void onZgloszenieEvent(ZgloszenieDomainEvent ev) {
        Long id = ev.getZgloszenieId();
        if (id == null) return;

        // Obsłuż dwa przypadki:
        // - CREATED: zgłoszenie utworzone od razu jako DONE
        // - UPDATED: zmiana statusu -> DONE
        switch (ev.getType()) {
            case CREATED -> handleIfDone(id, true);
            case UPDATED -> {
                if (ev.getChangedFields() == null || ev.getChangedFields().stream().noneMatch(f -> "status".equalsIgnoreCase(f))) {
                    return; // nie status
                }
                handleIfDone(id, false);
            }
            default -> {}
        }
    }

    private void handleIfDone(Long zgloszenieId, boolean created) {
        Zgloszenie z = zgloszenieRepository.findById(zgloszenieId).orElse(null);
        if (z == null) return;
        if (z.getStatus() != ZgloszenieStatus.DONE) return; // tylko zakończone

        var existing = raportRepository.findByZgloszenieId(zgloszenieId);
        if (existing.isPresent()) {
            // Aktualizuj istniejący raport ostatnimi danymi ze zgłoszenia (np. ponowne zamknięcie)
            Raport r = existing.get();
            r.setMaszyna(z.getMaszyna());
            r.setTypNaprawy(z.getTyp());
            r.setOpis(z.getOpis());
            r.setStatus(RaportStatus.ZAKONCZONE);
            var data = z.getCompletedAt() != null ? z.getCompletedAt().toLocalDate() : (r.getDataNaprawy() != null ? r.getDataNaprawy() : LocalDate.now());
            r.setDataNaprawy(data);
            if (z.getAcceptedAt() != null) r.setCzasOd(z.getAcceptedAt().toLocalTime());
            if (z.getCompletedAt() != null) r.setCzasDo(z.getCompletedAt().toLocalTime());
            if (z.getAutor() != null && (r.getCreatedBy() == null || r.getCreatedBy().isBlank())) r.setCreatedBy(z.getAutor().getUsername());
            raportRepository.save(r);
            log.info("Zaktualizowano raport {} ze zgloszenia {} (status DONE)", r.getId(), zgloszenieId);
            return;
        }

        // Brak – utwórz nowy raport
        Raport r = new Raport();
        r.setZgloszenieId(zgloszenieId);
        r.setMaszyna(z.getMaszyna());
        r.setTypNaprawy(z.getTyp());
        r.setOpis(z.getOpis());
        r.setStatus(RaportStatus.ZAKONCZONE);
        var data = z.getCompletedAt() != null ? z.getCompletedAt().toLocalDate() : LocalDate.now();
        r.setDataNaprawy(data);
        if (z.getAcceptedAt() != null) r.setCzasOd(z.getAcceptedAt().toLocalTime());
        if (z.getCompletedAt() != null) r.setCzasDo(z.getCompletedAt().toLocalTime());
        if (z.getAutor() != null) r.setCreatedBy(z.getAutor().getUsername());

        raportRepository.save(r);
        log.info("Utworzono raport {} ze zgloszenia {} ({} -> DONE)", r.getId(), zgloszenieId, created ? "CREATED" : "UPDATED");
    }
}
