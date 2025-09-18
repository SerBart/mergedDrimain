package drimer.drimain.repository;

import drimer.drimain.model.Zgloszenie;
import drimer.drimain.model.enums.ZgloszenieStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ZgloszenieRepository extends JpaRepository<Zgloszenie, Long>, JpaSpecificationExecutor<Zgloszenie> {
    
    // Find by status
    List<Zgloszenie> findByStatus(ZgloszenieStatus status);
    Page<Zgloszenie> findByStatus(ZgloszenieStatus status, Pageable pageable);
    
    // Find by typ
    List<Zgloszenie> findByTyp(String typ);
    Page<Zgloszenie> findByTyp(String typ, Pageable pageable);
    
    // Find by dzial
    List<Zgloszenie> findByDzialId(Long dzialId);
    Page<Zgloszenie> findByDzialId(Long dzialId, Pageable pageable);
    
    // Find by autor
    List<Zgloszenie> findByAutorId(Long autorId);
    Page<Zgloszenie> findByAutorId(Long autorId, Pageable pageable);
    
    // Complex search query
    @Query("SELECT z FROM Zgloszenie z WHERE " +
           "(:status IS NULL OR z.status = :status) AND " +
           "(:typ IS NULL OR z.typ LIKE %:typ%) AND " +
           "(:dzialId IS NULL OR z.dzial.id = :dzialId) AND " +
           "(:autorId IS NULL OR z.autor.id = :autorId) AND " +
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
}