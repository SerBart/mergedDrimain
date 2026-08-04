package drimer.drimain.repository;

import drimer.drimain.model.RaportZdjecieBlob;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface RaportZdjecieBlobRepository extends JpaRepository<RaportZdjecieBlob, Long> {

    Optional<RaportZdjecieBlob> findByRaportIdAndStoredFilename(Long raportId, String storedFilename);

    void deleteByRaportIdAndStoredFilename(Long raportId, String storedFilename);
}

