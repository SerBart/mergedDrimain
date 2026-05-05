package drimer.drimain.repository;

import drimer.drimain.model.Dzial;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface DzialRepository extends JpaRepository<Dzial, Long> {
    Optional<Dzial> findByNazwaIgnoreCase(String nazwa);
}