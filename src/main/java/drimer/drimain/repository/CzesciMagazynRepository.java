package drimer.drimain.repository;

import drimer.drimain.model.CzesciMagazyn;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface CzesciMagazynRepository extends JpaRepository<CzesciMagazyn, Long> {
}