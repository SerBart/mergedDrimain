package drimer.drimain.repository;

import drimer.drimain.model.Raport;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface RaportRepository extends JpaRepository<Raport, Long>, JpaSpecificationExecutor<Raport> {}