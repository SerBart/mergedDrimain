package drimer.drimain.repository;

import drimer.drimain.model.Raport;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface RaportRepository extends JpaRepository<Raport, Long>, JpaSpecificationExecutor<Raport> {

    @Override
    @EntityGraph(attributePaths = {"maszyna", "maszyna.dzial", "maszyna.sekcja", "osoba"})
    Page<Raport> findAll(Specification<Raport> spec, Pageable pageable);

    @Override
    @EntityGraph(attributePaths = {"maszyna", "maszyna.dzial", "maszyna.sekcja", "osoba", "partUsages", "partUsages.part", "zdjecia"})
    Optional<Raport> findById(Long id);

    @EntityGraph(attributePaths = {"maszyna", "maszyna.dzial", "maszyna.sekcja", "osoba", "partUsages", "partUsages.part", "zdjecia"})
    @Query("SELECT DISTINCT r FROM Raport r WHERE r.id IN :ids")
    List<Raport> findAllWithCollectionsByIdIn(@Param("ids") List<Long> ids);

    Optional<Raport> findByZgloszenieId(Long zgloszenieId);

    // Liczba raportow powiazanych z maszyna
    long countByMaszyna_Id(Long maszynaId);
}
