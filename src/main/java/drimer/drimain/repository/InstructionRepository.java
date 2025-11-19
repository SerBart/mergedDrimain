package drimer.drimain.repository;

import drimer.drimain.model.Instruction;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface InstructionRepository extends JpaRepository<Instruction, Long> {
    List<Instruction> findAllByOrderByCreatedAtDesc();
    List<Instruction> findByMaszyna_IdOrderByCreatedAtDesc(Long maszynaId);
    long countByMaszyna_Id(Long maszynaId);
}
