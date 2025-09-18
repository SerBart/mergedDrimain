package drimer.drimain.controller;

import drimer.drimain.events.EventType;
import drimer.drimain.service.SseSubscriptionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/zgloszenia")
@RequiredArgsConstructor
public class ZgloszenieStreamController {

    private final SseSubscriptionService sseSubscriptionService;

    /**
     * Subscribe to Server-Sent Events for zgloszenia changes.
     * 
     * @param types Comma-separated list of event types to filter (CREATED, UPDATED, DELETED, ATTACHMENT_ADDED, ATTACHMENT_REMOVED)
     * @param dzialId Filter by dzial ID (TODO: not implemented yet)
     * @param autorId Filter by autor ID (TODO: not implemented yet)  
     * @param full Include full entity snapshots in events (TODO: not implemented yet)
     * @return SseEmitter for streaming events
     */
    @GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter stream(
            @RequestParam(required = false) String types,
            @RequestParam(required = false) Long dzialId,
            @RequestParam(required = false) Long autorId,
            @RequestParam(defaultValue = "false") boolean full) {
        
        Set<EventType> eventTypes = null;
        
        if (types != null && !types.trim().isEmpty()) {
            eventTypes = Arrays.stream(types.split(","))
                    .map(String::trim)
                    .filter(s -> !s.isEmpty())
                    .map(s -> {
                        try {
                            return EventType.valueOf(s.toUpperCase());
                        } catch (IllegalArgumentException e) {
                            throw new IllegalArgumentException("Invalid event type: " + s);
                        }
                    })
                    .collect(Collectors.toSet());
        }

        return sseSubscriptionService.subscribe(eventTypes, dzialId, autorId, full);
    }

    /**
     * Get the number of active SSE subscriptions (for monitoring).
     */
    @GetMapping("/stream/status")
    public Object getStreamStatus() {
        return new Object() {
            public final int activeSubscriptions = sseSubscriptionService.getActiveSubscriptionCount();
            public final String status = "SSE service running";
        };
    }
}