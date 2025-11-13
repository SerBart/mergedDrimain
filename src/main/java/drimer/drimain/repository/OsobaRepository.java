package drimer.drimain.repository;

import drimer.drimain.model.Osoba;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface OsobaRepository extends JpaRepository<Osoba, Long> {
    Optional<Osoba> findByLogin(String login);

    List<Osoba> findByDzial_NazwaIgnoreCase(String nazwa);

    List<Osoba> findByDzial_Id(Long dzialId);
}