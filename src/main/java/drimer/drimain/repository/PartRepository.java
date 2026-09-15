package drimer.drimain.repository;

import drimer.drimain.model.Part;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface PartRepository extends JpaRepository<Part, Long> {
    long countByMaszyna_Id(Long maszynaId);

    @Query("""
            select p from Part p
            where lower(trim(p.nazwa)) = lower(trim(:nazwa))
              and lower(trim(coalesce(p.opis, ''))) = lower(trim(coalesce(:opis, '')))
              and lower(trim(coalesce(p.kategoria, ''))) = lower(trim(coalesce(:kategoria, '')))
            """)
    Optional<Part> findByNaturalKey(@Param("nazwa") String nazwa,
                                    @Param("opis") String opis,
                                    @Param("kategoria") String kategoria);
}