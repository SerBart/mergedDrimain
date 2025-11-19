package drimer.drimain.repository;

import drimer.drimain.model.Zgloszenie;
import drimer.drimain.model.enums.ZgloszenieStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ZgloszenieRepository extends JpaRepository<Zgloszenie, Long>, JpaSpecificationExecutor<Zgloszenie> {

    // Nadpisujemy findAll, aby dociągać relacje autor i dzial (unikamy LazyInitializationException przy mapowaniu)
    @Override
    @EntityGraph(attributePaths = {"autor", "dzial"})
    List<Zgloszenie> findAll();

    @Override
    @EntityGraph(attributePaths = {"autor", "dzial"})
    Page<Zgloszenie> findAll(Pageable pageable);

    @Override
    @EntityGraph(attributePaths = {"autor", "dzial"})
    Optional<Zgloszenie> findById(Long id);

    // Dodatkowe findery (z zachowaniem LAZY/EAGER wg potrzeb)
    List<Zgloszenie> findByStatus(ZgloszenieStatus status);
    Page<Zgloszenie> findByStatus(ZgloszenieStatus status, Pageable pageable);

    List<Zgloszenie> findByTyp(String typ);
    Page<Zgloszenie> findByTyp(String typ, Pageable pageable);

    List<Zgloszenie> findByDzialId(Long dzialId);
    Page<Zgloszenie> findByDzialId(Long dzialId, Pageable pageable);

    List<Zgloszenie> findByAutorId(Long autorId);
    Page<Zgloszenie> findByAutorId(Long autorId, Pageable pageable);

    // Przykładowe złożone filtrowanie (jeśli używane w projekcie)
    @Query("SELECT z FROM Zgloszenie z " +
            "LEFT JOIN z.dzial d " +
            "LEFT JOIN z.autor a " +
            "WHERE (:status IS NULL OR z.status = :status) AND " +
            "(:typ IS NULL OR z.typ LIKE %:typ%) AND " +
            "(:dzialId IS NULL OR d.id = :dzialId) AND " +
            "(:autorId IS NULL OR a.id = :autorId) AND " +
            "(:q IS NULL OR LOWER(z.opis) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
            "LOWER(z.imie) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
            "LOWER(z.nazwisko) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
            "LOWER(z.tytul) LIKE LOWER(CONCAT('%', :q, '%')))")
    Page<Zgloszenie> findWithFilters(@Param("status") ZgloszenieStatus status,
                                     @Param("typ") String typ,
                                     @Param("dzialId") Long dzialId,
                                     @Param("autorId") Long autorId,
                                     @Param("q") String q,
                                     Pageable pageable);

    // Liczba zgłoszeń powiązanych z maszyną
    long countByMaszyna_Id(Long maszynaId);
}