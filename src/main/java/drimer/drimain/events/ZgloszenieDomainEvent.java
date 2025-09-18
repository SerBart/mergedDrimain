package drimer.drimain.events;

import org.springframework.context.ApplicationEvent;

import java.time.LocalDateTime;
import java.util.List;

public class ZgloszenieDomainEvent extends ApplicationEvent {
    
    private final EventType type;
    private final Long zgloszenieId;
    private final LocalDateTime eventTimestamp;
    private final List<String> changedFields;
    private final Long attachmentId;
    private final Object snapshot; // TODO: For filtering by dzialId/autorId

    public ZgloszenieDomainEvent(Object source, EventType type, Long zgloszenieId) {
        this(source, type, zgloszenieId, null, null, null);
    }

    public ZgloszenieDomainEvent(Object source, EventType type, Long zgloszenieId, List<String> changedFields) {
        this(source, type, zgloszenieId, changedFields, null, null);
    }

    public ZgloszenieDomainEvent(Object source, EventType type, Long zgloszenieId, List<String> changedFields, Long attachmentId, Object snapshot) {
        super(source);
        this.type = type;
        this.zgloszenieId = zgloszenieId;
        this.eventTimestamp = LocalDateTime.now();
        this.changedFields = changedFields;
        this.attachmentId = attachmentId;
        this.snapshot = snapshot;
    }

    // Getters
    public EventType getType() {
        return type;
    }

    public Long getZgloszenieId() {
        return zgloszenieId;
    }

    public LocalDateTime getEventTimestamp() {
        return eventTimestamp;
    }

    public List<String> getChangedFields() {
        return changedFields;
    }

    public Long getAttachmentId() {
        return attachmentId;
    }

    public Object getSnapshot() {
        return snapshot;
    }
}