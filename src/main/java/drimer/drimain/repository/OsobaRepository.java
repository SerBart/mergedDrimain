package drimer.drimain.repository;

import drimer.drimain.model.Osoba;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface OsobaRepository extends JpaRepository<Osoba, Long> {
    Optional<Osoba> findByLogin(String login);
}