package drimer.drimain.repository;

import drimer.drimain.model.Osoba;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OsobaRepository extends JpaRepository<Osoba, Long> {
}