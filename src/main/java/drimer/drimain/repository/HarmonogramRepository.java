package drimer.drimain.repository;

import drimer.drimain.model.Harmonogram;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface HarmonogramRepository extends JpaRepository<Harmonogram, Long> {
    List<Harmonogram> findByDataBetween(LocalDate start, LocalDate end);

    // Eager fetch dla relacji używanych w DTO, by uniknąć LazyInitializationException
    @Query("select distinct h from Harmonogram h left join fetch h.dzial left join fetch h.maszyna left join fetch h.osoba")
    List<Harmonogram> findAllWithJoins();

    // Filtrowanie po dacie z join fetchami
    @Query("select distinct h from Harmonogram h left join fetch h.dzial left join fetch h.maszyna left join fetch h.osoba where h.data between :start and :end")
    List<Harmonogram> findByDataBetweenWithJoins(@Param("start") LocalDate start, @Param("end") LocalDate end);

    // Liczba harmonogramów powiązanych z maszyną
    long countByMaszyna_Id(Long maszynaId);
}