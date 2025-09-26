package drimer.drimain.repository;

import drimer.drimain.model.InstructionPart;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface InstructionPartRepository extends JpaRepository<InstructionPart, Long> {
    List<InstructionPart> findByInstruction_Id(Long instructionId);
}

