package drimer.drimain.config;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.exception.FlywayValidateException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.flyway.FlywayMigrationStrategy;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class FlywayRepairConfiguration {

    private static final Logger log = LoggerFactory.getLogger(FlywayRepairConfiguration.class);

    @Bean
    public FlywayMigrationStrategy flywayMigrationStrategy() {
        return flyway -> {
            try {
                flyway.migrate();
            } catch (FlywayValidateException e) {
                log.warn("[FLYWAY] Wykryto niezgodność checksum migracji. Uruchamiam flyway.repair() i ponawiam migrate()...");
                log.warn("[FLYWAY] Szczegóły: {}", e.getMessage());
                flyway.repair();
                log.info("[FLYWAY] repair() zakończony. Ponawiam flyway.migrate()...");
                flyway.migrate();
                log.info("[FLYWAY] Migracja zakończona pomyślnie po repair().");
            }
        };
    }
}
