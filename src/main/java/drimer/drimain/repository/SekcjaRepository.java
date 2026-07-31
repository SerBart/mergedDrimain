package drimer.drimain.repository;

import drimer.drimain.model.Sekcja;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SekcjaRepository extends JpaRepository<Sekcja, Long> {
    List<Sekcja> findByMaszyna_IdOrderByNazwaAsc(Long maszynaId);
    List<Sekcja> findByMaszyna_Dzial_IdOrderByNazwaAsc(Long dzialId);
    List<Sekcja> findAllByOrderByNazwaAsc();
    Optional<Sekcja> findByMaszyna_IdAndNazwaIgnoreCase(Long maszynaId, String nazwa);
    long countByMaszyna_Id(Long maszynaId);
}

