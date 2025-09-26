package drimer.drimain.api.dto;

import java.time.LocalDateTime;

public class InstructionAttachmentDTO {
    public Long id;
    public String originalFilename;
    public String contentType;
    public Long fileSize;
    public LocalDateTime createdAt;
    public String createdBy;
}

