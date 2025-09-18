package drimer.drimain.api.dto;

import drimer.drimain.events.EventType;
import java.time.LocalDateTime;
import java.util.List;

public class ZgloszenieEventDTO {
    private EventType type;
    private Long zgloszenieId;
    private LocalDateTime eventTimestamp;
    private List<String> changedFields;
    private Long attachmentId;
    
    // For serialization
    public ZgloszenieEventDTO() {}

    public ZgloszenieEventDTO(EventType type, Long zgloszenieId, LocalDateTime eventTimestamp, List<String> changedFields, Long attachmentId) {
        this.type = type;
        this.zgloszenieId = zgloszenieId;
        this.eventTimestamp = eventTimestamp;
        this.changedFields = changedFields;
        this.attachmentId = attachmentId;
    }

    // Getters and setters
    public EventType getType() {
        return type;
    }

    public void setType(EventType type) {
        this.type = type;
    }

    public Long getZgloszenieId() {
        return zgloszenieId;
    }

    public void setZgloszenieId(Long zgloszenieId) {
        this.zgloszenieId = zgloszenieId;
    }

    public LocalDateTime getEventTimestamp() {
        return eventTimestamp;
    }

    public void setEventTimestamp(LocalDateTime eventTimestamp) {
        this.eventTimestamp = eventTimestamp;
    }

    public List<String> getChangedFields() {
        return changedFields;
    }

    public void setChangedFields(List<String> changedFields) {
        this.changedFields = changedFields;
    }

    public Long getAttachmentId() {
        return attachmentId;
    }

    public void setAttachmentId(Long attachmentId) {
        this.attachmentId = attachmentId;
    }
}