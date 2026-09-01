package drimer.drimain.repository;

import drimer.drimain.model.EnergyReading;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface EnergyReadingRepository extends JpaRepository<EnergyReading, Long> {

    @EntityGraph(attributePaths = {"maszyna", "maszyna.dzial", "maszyna.sekcja"})
    List<EnergyReading> findByRecordedAtBetweenOrderByRecordedAtAsc(LocalDateTime from, LocalDateTime to);

    @EntityGraph(attributePaths = {"maszyna", "maszyna.dzial", "maszyna.sekcja"})
    List<EnergyReading> findByMaszyna_IdAndRecordedAtBetweenOrderByRecordedAtAsc(Long maszynaId, LocalDateTime from, LocalDateTime to);

    @EntityGraph(attributePaths = {"maszyna", "maszyna.dzial", "maszyna.sekcja"})
    Optional<EnergyReading> findTopByMaszyna_IdOrderByRecordedAtDesc(Long maszynaId);
}

