package drimer.drimain.api.mapper;

import drimer.drimain.api.dto.AttachmentDTO;
import drimer.drimain.model.Attachment;
import org.springframework.stereotype.Component;

@Component
public class AttachmentMapper {

    public AttachmentDTO toDto(Attachment attachment) {
        if (attachment == null) {
            return null;
        }
        
        AttachmentDTO dto = new AttachmentDTO();
        dto.setId(attachment.getId());
        dto.setOriginalFilename(attachment.getOriginalFilename());
        dto.setContentType(attachment.getContentType());
        dto.setFileSize(attachment.getFileSize());
        dto.setCreatedAt(attachment.getCreatedAt());
        dto.setCreatedBy(attachment.getCreatedBy());
        
        // Generate download URL
        dto.setDownloadUrl("/api/attachments/" + attachment.getId() + "/download");
        
        return dto;
    }
}