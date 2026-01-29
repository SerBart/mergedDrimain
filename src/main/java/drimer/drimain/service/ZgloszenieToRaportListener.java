package drimer.drimain.service;

import drimer.drimain.events.EventType;
import drimer.drimain.events.ZgloszenieDomainEvent;
import drimer.drimain.model.Raport;
import drimer.drimain.model.Zgloszenie;
import drimer.drimain.model.enums.RaportStatus;
import drimer.drimain.model.enums.ZgloszenieStatus;
import drimer.drimain.repository.RaportRepository;
import drimer.drimain.repository.ZgloszenieRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

/**
 * Listener do automatycznego tworzenia raportu gdy zgłoszenie zmieni status na DONE.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ZgloszenieToRaportListener {

    private final ZgloszenieRepository zgloszenieRepository;
    private final RaportRepository raportRepository;

    /**
     * Gdy zgłoszenie zostanie zmienione, sprawdzamy czy status zmienił się na DONE.
     * Jeśli tak, tworzymy automatycznie raport na podstawie zgłoszenia.
     */
    @EventListener
    @Transactional
    public void onZgloszenieUpdated(ZgloszenieDomainEvent event) {
        // Interesują nas tylko eventy UPDATED
        if (event.getType() != EventType.UPDATED) {
            return;
        }

        // Pobierz zgłoszenie
        Zgloszenie zgloszenie = zgloszenieRepository.findById(event.getZgloszenieId())
                .orElse(null);

        if (zgloszenie == null) {
            log.warn("Zgloszenie with ID {} not found for event processing", event.getZgloszenieId());
            return;
        }

        // Sprawdź czy status zmienił się na DONE
        if (zgloszenie.getStatus() != ZgloszenieStatus.DONE) {
            return;
        }

        // Sprawdź czy już istnieje raport dla tego zgłoszenia (idempotencja)
        boolean raportExists = raportRepository.findAll().stream()
                .anyMatch(r -> r.getZgloszenieId() != null &&
                             r.getZgloszenieId().equals(zgloszenie.getId()));

        if (raportExists) {
            log.info("Raport already exists for zgloszenie {}, skipping creation", zgloszenie.getId());
            return;
        }

        try {
            // Tworzenie raportu na podstawie zgłoszenia
            Raport raport = new Raport();

            // Ustaw pola z zgłoszenia
            raport.setTypNaprawy(zgloszenie.getTyp());
            raport.setOpis(zgloszenie.getOpis());
            raport.setDataNaprawy(LocalDate.now());
            raport.setStatus(RaportStatus.NOWY);

            // Ustaw maszynę z zgłoszenia
            if (zgloszenie.getMaszyna() != null) {
                raport.setMaszyna(zgloszenie.getMaszyna());
            }

            // Ustaw osobę z autora zgłoszenia jeśli dostępna
            // (Raport.osoba to Osoba, a Zgloszenie.autor to User, więc mogą być niezgodne)
            // W tym przypadku pozostawiamy null, ale można dodać mapowanie

            // Ustaw identyfikator źródłowego zgłoszenia dla idempotencji
            raport.setZgloszenieId(zgloszenie.getId());

            // Ustaw twórcę raportu
            if (zgloszenie.getAutor() != null) {
                raport.setCreatedBy(zgloszenie.getAutor().getUsername());
            }

            // Zapisz raport
            Raport saved = raportRepository.save(raport);

            log.info("Automatically created raport with ID {} for closed zgloszenie {}",
                    saved.getId(), zgloszenie.getId());

        } catch (Exception e) {
            log.error("Error creating raport for zgloszenie {}: {}",
                    zgloszenie.getId(), e.getMessage(), e);
            // Nie rzucamy wyjątku - chcemy aby zamknięcie zgłoszenia powiodło się
            // nawet jeśli tworzenie raportu się nie powiedzie
        }
    }
}
