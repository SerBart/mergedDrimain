package drimer.drimain.repository;

import drimer.drimain.model.InstructionAttachment;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface InstructionAttachmentRepository extends JpaRepository<InstructionAttachment, Long> {
    List<InstructionAttachment> findByInstruction_IdOrderByCreatedAtDesc(Long instructionId);
}

