package drimer.drimain.config;

import drimer.drimain.model.Harmonogram;
import drimer.drimain.model.enums.StatusHarmonogramu;
import drimer.drimain.repository.HarmonogramRepository;
import jakarta.transaction.Transactional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.util.Locale;

/**
 * Jednorazowy migrator starych wartości tekstowych statusu.
 * UWAGA: Usunięto @DependsOn("flyway") aby uniknąć cyklu zależności
 * 'flyway' <-> 'entityManagerFactory'. Flyway i tak wykona migracje
 * przed uruchomieniem ApplicationRunner.
 */
@Component
@Profile({"dev","default"})
public class StatusMigrationInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(StatusMigrationInitializer.class);

    private final HarmonogramRepository harmonogramRepository;

    public StatusMigrationInitializer(HarmonogramRepository harmonogramRepository) {
        this.harmonogramRepository = harmonogramRepository;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        long updated = harmonogramRepository.findAll().stream()
                .filter(h -> {
                    if (h.getStatus() == null) {
                        h.setStatus(StatusHarmonogramu.PLANOWANE);
                        return true;
                    }
                    return false;
                })
                .count();

        if (updated > 0) {
            harmonogramRepository.flush();
            log.info("Zaktualizowano {} rekordów Harmonogram (null -> PLANOWANE)", updated);
        }
    }
}