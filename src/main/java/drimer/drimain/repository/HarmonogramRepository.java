package drimer.drimain.repository;

import drimer.drimain.model.Harmonogram;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface HarmonogramRepository extends JpaRepository<Harmonogram, Long> {
    List<Harmonogram> findByDataBetween(LocalDate start, LocalDate end);
}