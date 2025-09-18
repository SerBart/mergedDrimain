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
 * Jednorazowy migrator starych wartości tekstowych statusu (np. "brak czesc", "oczekiwanie na czesc")
 * do odpowiednich enumów. Po skutecznym przejściu można klasę usunąć lub oznaczyć profilem dev.
 */
@Component
@Profile({"dev","default"}) // dostosuj do swoich profili – lub usuń adnotację jeśli ma działać zawsze
public class StatusMigrationInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(StatusMigrationInitializer.class);

    private final HarmonogramRepository harmonogramRepository;

    public StatusMigrationInitializer(HarmonogramRepository harmonogramRepository) {
        this.harmonogramRepository = harmonogramRepository;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        // Jeśli pole już jest typu enum, a stare dane (String) zostały zmapowane przez JPA -> nic nie trzeba.
        // Ten kod ma sens jeśli PRZED zmianą odczytałeś istniejące rekordy JAKO String i baza zawiera stare formy,
        // a teraz chcesz je „znormalizować” (np. jeśli kolumnę zostawiłeś typu VARCHAR i wprowadzałeś ręcznie).
        long updated = harmonogramRepository.findAll().stream()
                .filter(h -> {
                    // Jeżeli status jest null (stare rekordy), ustaw PLANOWANE
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

        // Jeśli PRZED zmianą miałeś czyste Stringi w bazie typu 'brak czesc' a teraz już JPA mapuje enum,
        // to zmiana musiała być poprzedzona ALTER TABLE / czyszczeniem – inaczej rekordy nie zmapują się.
        // Jeżeli jednak nadal masz takie surowe wartości i nie możesz zmienić kolumny,
        // użyj zapytań SQL ręcznie / Flyway migracji.
    }
}