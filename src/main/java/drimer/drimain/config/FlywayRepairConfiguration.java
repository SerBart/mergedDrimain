package drimer.drimain.config;

import org.flywaydb.core.Flyway;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.flyway.FlywayMigrationStrategy;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;

@Configuration
public class FlywayRepairConfiguration {

    private static final Logger log = LoggerFactory.getLogger(FlywayRepairConfiguration.class);
    private static final String REPAIR_PROPERTY = "app.flyway.repair-on-startup";
    private static final String REPAIR_ENV = "FLYWAY_REPAIR_ON_STARTUP";

    @Bean
    public FlywayMigrationStrategy flywayMigrationStrategy(Environment environment) {
        return flyway -> migrateWithOptionalRepair(flyway, environment);
    }

    private void migrateWithOptionalRepair(Flyway flyway, Environment environment) {
        boolean repairOnStartup = environment.getProperty(REPAIR_PROPERTY, Boolean.class, false)
                || environment.getProperty(REPAIR_ENV, Boolean.class, false);

        if (repairOnStartup) {
            log.warn("[FLYWAY] {}=true -> uruchamiam flyway.repair() przed migrate(). Użyj tylko jednorazowo po zmianie checksum migracji.", REPAIR_ENV);
            flyway.repair();
            log.warn("[FLYWAY] flyway.repair() zakończony. Uruchamiam flyway.migrate().");
        }

        flyway.migrate();
    }
}

