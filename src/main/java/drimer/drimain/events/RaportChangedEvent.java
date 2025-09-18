package drimer.drimain.events;

import drimer.drimain.api.dto.RaportDTO;
import org.springframework.context.ApplicationEvent;

public class RaportChangedEvent extends ApplicationEvent {
    private final RaportDTO raport;
    private final String action; // CREATED / UPDATED / DELETED

    public RaportChangedEvent(Object source, RaportDTO raport, String action) {
        super(source);
        this.raport = raport;
        this.action = action;
    }

    public RaportDTO getRaport() { return raport; }
    public String getAction() { return action; }
}