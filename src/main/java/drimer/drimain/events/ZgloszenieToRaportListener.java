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
import java.time.LocalTime;

@Component
@RequiredArgsConstructor
@Slf4j
public class ZgloszenieToRaportListener {

    private final ZgloszenieRepository zgloszenieRepository;
    private final RaportRepository raportRepository;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional
    public void onZgloszenieUpdated(ZgloszenieDomainEvent ev) {
        if (ev.getType() != EventType.UPDATED) return;
        // Szybka ścieżka: reaguj tylko gdy mogła zmienić się kolumna status
        if (ev.getChangedFields() == null || ev.getChangedFields().stream().noneMatch(f -> "status".equalsIgnoreCase(f))) {
            return;
        }
        Long id = ev.getZgloszenieId();
        if (id == null) return;

        Zgloszenie z = zgloszenieRepository.findById(id).orElse(null);
        if (z == null) return;
        if (z.getStatus() != ZgloszenieStatus.DONE) return; // tylko zakończone

        // Idempotencja: jeśli raport już istnieje dla tego zgłoszenia – nic nie rób
        if (raportRepository.findByZgloszenieId(id).isPresent()) {
            log.debug("Raport dla zgloszenieId={} już istnieje – pomijam.", id);
            return;
        }

        Raport r = new Raport();
        r.setZgloszenieId(id);
        r.setMaszyna(z.getMaszyna());
        r.setTypNaprawy(z.getTyp());
        r.setOpis(z.getOpis());
        r.setStatus(RaportStatus.ZAKONCZONE);
        // Daty/czasy z accepted/completed
        LocalDate data = z.getCompletedAt() != null ? z.getCompletedAt().toLocalDate() : LocalDate.now();
        r.setDataNaprawy(data);
        if (z.getAcceptedAt() != null) r.setCzasOd(LocalTime.from(z.getAcceptedAt()));
        if (z.getCompletedAt() != null) r.setCzasDo(LocalTime.from(z.getCompletedAt()));
        if (z.getAutor() != null) r.setCreatedBy(z.getAutor().getUsername());

        raportRepository.save(r);
        log.info("Utworzono raport {} ze zgloszenia {} (status DONE)", r.getId(), id);
    }
}

