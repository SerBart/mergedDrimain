package drimer.drimain.repository;

import drimer.drimain.model.Przeglad;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;

public interface PrzegladRepository extends JpaRepository<Przeglad, Long> {
    List<Przeglad> findByDataBetween(LocalDate start, LocalDate end);
}