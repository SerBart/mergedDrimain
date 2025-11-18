package drimer.drimain.repository;

import drimer.drimain.model.Maszyna;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MaszynaRepository extends JpaRepository<Maszyna, Long> {
    List<Maszyna> findByDzial_Id(Long dzialId);
    List<Maszyna> findByDzial_NazwaIgnoreCase(String nazwa);
}
