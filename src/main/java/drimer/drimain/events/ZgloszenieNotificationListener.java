package drimer.drimain.events;

import drimer.drimain.model.Notification;
import drimer.drimain.model.NotificationType;
import drimer.drimain.model.Zgloszenie;
import drimer.drimain.repository.ZgloszenieRepository;
import drimer.drimain.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Propagation;

/**
 * Listener do automatycznego tworzenia powiadomień dla zgłoszeń.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class ZgloszenieNotificationListener {

    private final ZgloszenieRepository zgloszenieRepository;
    private final NotificationService notificationService;

    /**
     * Gdy zgłoszenie zostanie utworzone, tworzymy powiadomienie modułowe.
     */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onZgloszenieEvent(ZgloszenieDomainEvent event) {
        Long zgloszenieId = event.getZgloszenieId();
        if (zgloszenieId == null) return;

        Zgloszenie zgloszenie = zgloszenieRepository.findById(zgloszenieId).orElse(null);
        if (zgloszenie == null) {
            log.warn("Zgloszenie with ID {} not found for notification", zgloszenieId);
            return;
        }

        switch (event.getType()) {
            case CREATED:
                createNewZgloszenieNotification(zgloszenie);
                break;
            case UPDATED:
                // Powiadomienie o aktualizacji statusu (opcjonalne)
                if (event.getChangedFields() != null && event.getChangedFields().contains("status")) {
                    createStatusChangeNotification(zgloszenie);
                }
                break;
            default:
                break;
        }
    }

    private void createNewZgloszenieNotification(Zgloszenie zgloszenie) {
        try {
            String title = "Nowe zgłoszenie: " + zgloszenie.getTyp();
            String message = "Zgłoszenie od " + zgloszenie.getImie() + " " + zgloszenie.getNazwisko() +
                           ": " + zgloszenie.getOpis();
            String link = "/zgloszenia/" + zgloszenie.getId();

            Notification notif = notificationService.createModuleNotification(
                    "Zgloszenia",
                    NotificationType.NEW_ZGLOSZENIE,
                    title,
                    message,
                    link
            );

            if (notif != null) {
                log.info("Created notification for new zgloszenie {} with title: {}",
                        zgloszenie.getId(), title);
            }
        } catch (Exception e) {
            log.error("Error creating notification for zgloszenie {}: {}",
                    zgloszenie.getId(), e.getMessage(), e);
        }
    }

    private void createStatusChangeNotification(Zgloszenie zgloszenie) {
        try {
            String title = "Zmiana statusu zgłoszenia: " + zgloszenie.getStatus();
            String message = "Zgłoszenie ID " + zgloszenie.getId() + " zmienił status na: " + zgloszenie.getStatus();
            String link = "/zgloszenia/" + zgloszenie.getId();

            notificationService.createModuleNotification(
                    "Zgloszenia",
                    NotificationType.GENERIC,
                    title,
                    message,
                    link
            );

            log.info("Created status change notification for zgloszenie {}", zgloszenie.getId());
        } catch (Exception e) {
            log.error("Error creating status change notification for zgloszenie {}: {}",
                    zgloszenie.getId(), e.getMessage(), e);
        }
    }
}
