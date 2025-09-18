package drimer.drimain.api.dto;

import java.util.List;

public class AttachmentUploadResponse {
    private List<AttachmentDTO> attachments;
    private String message;

    public AttachmentUploadResponse() {}

    public AttachmentUploadResponse(List<AttachmentDTO> attachments, String message) {
        this.attachments = attachments;
        this.message = message;
    }

    // Getters and setters
    public List<AttachmentDTO> getAttachments() {
        return attachments;
    }

    public void setAttachments(List<AttachmentDTO> attachments) {
        this.attachments = attachments;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }
}