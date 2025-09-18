package drimer.drimain.service;

import drimer.drimain.api.dto.ZgloszenieEventDTO;
import drimer.drimain.config.SseProperties;
import drimer.drimain.events.EventType;
import drimer.drimain.events.ZgloszenieDomainEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
@Slf4j
public class SseSubscriptionService {

    private final SseProperties sseProperties;
    private final Map<String, SseEmitter> subscriptions = new ConcurrentHashMap<>();
    private final Map<String, SubscriptionInfo> subscriptionInfo = new ConcurrentHashMap<>();

    public SseEmitter subscribe(Set<EventType> eventTypes, Long dzialId, Long autorId, boolean full) {
        if (subscriptions.size() >= sseProperties.getMaxClients()) {
            throw new IllegalStateException("Maximum number of SSE clients reached");
        }

        String subscriptionId = UUID.randomUUID().toString();
        SseEmitter emitter = new SseEmitter(sseProperties.getClientTimeoutSeconds() * 1000);

        // Configure emitter callbacks
        emitter.onCompletion(() -> removeSubscription(subscriptionId));
        emitter.onTimeout(() -> removeSubscription(subscriptionId));
        emitter.onError(e -> removeSubscription(subscriptionId));

        // Store subscription
        subscriptions.put(subscriptionId, emitter);
        subscriptionInfo.put(subscriptionId, new SubscriptionInfo(
                eventTypes, dzialId, autorId, full, LocalDateTime.now()
        ));

        try {
            // Send initial event
            ZgloszenieEventDTO initEvent = new ZgloszenieEventDTO(
                    null, null, LocalDateTime.now(), Collections.emptyList(), null
            );
            initEvent.setType(null); // Special INIT event marker
            emitter.send(SseEmitter.event()
                    .name("INIT")
                    .data(initEvent)
            );
        } catch (IOException e) {
            log.warn("Failed to send initial event to subscription {}", subscriptionId, e);
            removeSubscription(subscriptionId);
        }

        log.debug("SSE subscription {} created. Active subscriptions: {}", subscriptionId, subscriptions.size());
        return emitter;
    }

    @EventListener
    public void onZgloszenieEvent(ZgloszenieDomainEvent event) {
        ZgloszenieEventDTO eventDto = new ZgloszenieEventDTO(
                event.getType(),
                event.getZgloszenieId(),
                event.getEventTimestamp(),
                event.getChangedFields(),
                event.getAttachmentId()
        );

        List<String> failedSubscriptions = new ArrayList<>();

        subscriptions.entrySet().parallelStream().forEach(entry -> {
            String subscriptionId = entry.getKey();
            SseEmitter emitter = entry.getValue();
            SubscriptionInfo info = subscriptionInfo.get(subscriptionId);

            if (info != null && shouldSendEvent(event, info)) {
                try {
                    emitter.send(SseEmitter.event()
                            .name(event.getType().name())
                            .data(eventDto)
                    );
                } catch (IOException e) {
                    log.warn("Failed to send event to subscription {}", subscriptionId, e);
                    synchronized (failedSubscriptions) {
                        failedSubscriptions.add(subscriptionId);
                    }
                }
            }
        });

        // Clean up failed subscriptions
        failedSubscriptions.forEach(this::removeSubscription);
    }

    @Scheduled(fixedDelayString = "#{sseProperties.heartbeatIntervalSeconds * 1000}")
    public void sendHeartbeat() {
        if (subscriptions.isEmpty()) {
            return;
        }

        List<String> failedSubscriptions = new ArrayList<>();
        
        subscriptions.entrySet().parallelStream().forEach(entry -> {
            String subscriptionId = entry.getKey();
            SseEmitter emitter = entry.getValue();

            try {
                emitter.send(SseEmitter.event()
                        .name("HEARTBEAT")
                        .data("ping")
                );
            } catch (IOException e) {
                log.debug("Heartbeat failed for subscription {}", subscriptionId, e);
                synchronized (failedSubscriptions) {
                    failedSubscriptions.add(subscriptionId);
                }
            }
        });

        failedSubscriptions.forEach(this::removeSubscription);
        
        if (!subscriptions.isEmpty()) {
            log.debug("Sent heartbeat to {} active SSE subscriptions", subscriptions.size());
        }
    }

    private boolean shouldSendEvent(ZgloszenieDomainEvent event, SubscriptionInfo info) {
        // Filter by event type
        if (info.eventTypes != null && !info.eventTypes.isEmpty() && !info.eventTypes.contains(event.getType())) {
            return false;
        }

        // TODO: Filter by dzialId/autorId requires snapshot implementation
        // Currently not filtering by dzialId/autorId as noted in requirements
        
        return true;
    }

    private void removeSubscription(String subscriptionId) {
        subscriptions.remove(subscriptionId);
        subscriptionInfo.remove(subscriptionId);
        log.debug("SSE subscription {} removed. Active subscriptions: {}", subscriptionId, subscriptions.size());
    }

    public int getActiveSubscriptionCount() {
        return subscriptions.size();
    }

    private static class SubscriptionInfo {
        final Set<EventType> eventTypes;
        final Long dzialId;
        final Long autorId;
        final boolean full;
        final LocalDateTime createdAt;

        SubscriptionInfo(Set<EventType> eventTypes, Long dzialId, Long autorId, boolean full, LocalDateTime createdAt) {
            this.eventTypes = eventTypes;
            this.dzialId = dzialId;
            this.autorId = autorId;
            this.full = full;
            this.createdAt = createdAt;
        }
    }
}