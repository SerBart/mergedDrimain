package drimer.drimain.repository;

import drimer.drimain.model.Sekcja;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SekcjaRepository extends JpaRepository<Sekcja, Long> {
    List<Sekcja> findByDzial_IdOrderByNazwaAsc(Long dzialId);
    List<Sekcja> findAllByOrderByNazwaAsc();
    Optional<Sekcja> findByDzial_IdAndNazwaIgnoreCase(Long dzialId, String nazwa);
}

