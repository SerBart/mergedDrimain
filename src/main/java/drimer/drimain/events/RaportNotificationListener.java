package drimer.drimain.events;

import drimer.drimain.api.dto.RaportDTO;
import drimer.drimain.model.NotificationType;
import drimer.drimain.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * Listener do automatycznego tworzenia powiadomień dla raportów.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class RaportNotificationListener {

    private final NotificationService notificationService;

    /**
     * Gdy raport zostanie utworzony lub zmieniony, tworzymy powiadomienie modułowe.
     */
    @EventListener
    public void onRaportChanged(RaportChangedEvent event) {
        RaportDTO raport = event.getRaport();
        String action = event.getAction();

        if (raport == null || raport.getId() == null) {
            log.warn("RaportDTO or ID is null for notification");
            return;
        }

        try {
            switch (action) {
                case "CREATED":
                    createNewRaportNotification(raport);
                    break;
                case "UPDATED":
                    createRaportUpdatedNotification(raport);
                    break;
                case "DELETED":
                    createRaportDeletedNotification(raport);
                    break;
                default:
                    log.debug("Unknown action for raport notification: {}", action);
            }
        } catch (Exception e) {
            log.error("Error creating raport notification for raport {}: {}",
                    raport.getId(), e.getMessage(), e);
        }
    }

    private void createNewRaportNotification(RaportDTO raport) {
        String title = "Nowy raport: " + raport.getTypNaprawy();
        String message = "Raport dla maszyny " + (raport.getMaszyna() != null ? raport.getMaszyna().getNazwa() : "?") +
                        " - " + raport.getOpis();
        String link = "/raporty/" + raport.getId();

        notificationService.createModuleNotification(
                "Raporty",
                NotificationType.GENERIC,
                title,
                message,
                link
        );

        log.info("Created notification for new raport {} with title: {}",
                raport.getId(), title);
    }

    private void createRaportUpdatedNotification(RaportDTO raport) {
        String title = "Raport zaktualizowany: " + raport.getTypNaprawy();
        String message = "Raport ID " + raport.getId() + " został zaktualizowany";
        String link = "/raporty/" + raport.getId();

        notificationService.createModuleNotification(
                "Raporty",
                NotificationType.GENERIC,
                title,
                message,
                link
        );

        log.info("Created update notification for raport {}", raport.getId());
    }

    private void createRaportDeletedNotification(RaportDTO raport) {
        String title = "Raport usunięty: " + raport.getTypNaprawy();
        String message = "Raport ID " + raport.getId() + " został usunięty";
        String link = "/raporty";

        notificationService.createModuleNotification(
                "Raporty",
                NotificationType.GENERIC,
                title,
                message,
                link
        );

        log.info("Created delete notification for raport {}", raport.getId());
    }
}

