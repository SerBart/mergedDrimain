package drimer.drimain.repository;

import drimer.drimain.model.Harmonogram;
import drimer.drimain.model.enums.StatusHarmonogramu;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface HarmonogramRepository extends JpaRepository<Harmonogram, Long> {

    List<Harmonogram> findByDataBetween(LocalDate start, LocalDate end);

    @Query("select distinct h from Harmonogram h left join fetch h.dzial left join fetch h.maszyna left join fetch h.osoba left join fetch h.zalaczniki")
    List<Harmonogram> findAllWithJoins();

    @Query("select distinct h from Harmonogram h left join fetch h.dzial left join fetch h.maszyna left join fetch h.osoba left join fetch h.zalaczniki where h.data between :start and :end")
    List<Harmonogram> findByDataBetweenWithJoins(@Param("start") LocalDate start, @Param("end") LocalDate end);

    @Query("select distinct h from Harmonogram h left join fetch h.dzial left join fetch h.maszyna left join fetch h.osoba left join fetch h.zalaczniki where h.id = :id")
    List<Harmonogram> findByIdWithJoins(@Param("id") Long id);

    List<Harmonogram> findBySeriesIdAndDataAfterOrderByDataAsc(String seriesId, LocalDate date);

    List<Harmonogram> findBySeriesIdAndDataGreaterThanEqualAndStatus(String seriesId, LocalDate date, StatusHarmonogramu status);

    long countBySeriesIdAndDataAfter(String seriesId, LocalDate date);

    long countByMaszyna_Id(Long maszynaId);
}