package drimer.drimain.api.dto;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

public class AnnouncementDTO {
    private Long id;
    private String title;
    private String content;
    private Instant createdAt;
    private String createdByUsername;
    private boolean active;
    private String targetType;
    private Long targetDzialId;
    private String targetDzialNazwa;
    private List<Long> targetUserIds = new ArrayList<>();
    private List<AnnouncementAttachmentDTO> attachments = new ArrayList<>();

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public String getCreatedByUsername() {
        return createdByUsername;
    }

    public void setCreatedByUsername(String createdByUsername) {
        this.createdByUsername = createdByUsername;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    public String getTargetType() {
        return targetType;
    }

    public void setTargetType(String targetType) {
        this.targetType = targetType;
    }

    public Long getTargetDzialId() {
        return targetDzialId;
    }

    public void setTargetDzialId(Long targetDzialId) {
        this.targetDzialId = targetDzialId;
    }

    public String getTargetDzialNazwa() {
        return targetDzialNazwa;
    }

    public void setTargetDzialNazwa(String targetDzialNazwa) {
        this.targetDzialNazwa = targetDzialNazwa;
    }

    public List<Long> getTargetUserIds() {
        return targetUserIds;
    }

    public void setTargetUserIds(List<Long> targetUserIds) {
        this.targetUserIds = targetUserIds;
    }

    public List<AnnouncementAttachmentDTO> getAttachments() {
        return attachments;
    }

    public void setAttachments(List<AnnouncementAttachmentDTO> attachments) {
        this.attachments = attachments;
    }
}

