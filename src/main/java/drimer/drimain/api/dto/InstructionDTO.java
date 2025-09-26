package drimer.drimain.api.dto;

import java.time.LocalDateTime;
import java.util.List;

public class InstructionDTO {
    public Long id;
    public String title;
    public String description;
    public Long maszynaId;
    public String maszynaNazwa;
    public LocalDateTime createdAt;
    public String createdBy;
    public List<InstructionPartDTO> parts;
    public List<InstructionAttachmentDTO> attachments;
}

