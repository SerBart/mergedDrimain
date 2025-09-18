package drimer.drimain.events;

import lombok.RequiredArgsConstructor;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class RaportEventListener {

    private final SimpMessagingTemplate template;

    @EventListener
    public void onRaportChanged(RaportChangedEvent ev) {
        template.convertAndSend("/topic/raporty", ev);
    }
}