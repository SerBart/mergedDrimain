package drimer.drimain.repository;

import drimer.drimain.model.Raport;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.domain.Specification;

import java.util.Optional;

public interface RaportRepository extends JpaRepository<Raport, Long>, JpaSpecificationExecutor<Raport> {

    @Override
    @EntityGraph(attributePaths = {"maszyna", "osoba", "partUsages", "partUsages.part"})
    Page<Raport> findAll(Specification<Raport> spec, Pageable pageable);

    @Override
    @EntityGraph(attributePaths = {"maszyna", "osoba", "partUsages", "partUsages.part"})
    Optional<Raport> findById(Long id);

    Optional<Raport> findByZgloszenieId(Long zgloszenieId);

    // Liczba raportów powiązanych z maszyną
    long countByMaszyna_Id(Long maszynaId);
}
