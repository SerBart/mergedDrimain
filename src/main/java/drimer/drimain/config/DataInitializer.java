package drimer.drimain.config;

import drimer.drimain.model.Role;
import drimer.drimain.model.User;
import drimer.drimain.model.Dzial;
import drimer.drimain.repository.RoleRepository;
import drimer.drimain.repository.UserRepository;
import drimer.drimain.repository.DzialRepository;
// usuń import org.flywaydb.core.Flyway; i ConditionalOnBean
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import lombok.extern.slf4j.Slf4j;

import java.util.Set;
import java.util.List;

@Component
@Order(10) // Initialize roles and users
@Slf4j
public class DataInitializer implements ApplicationRunner {

    private final RoleRepository roleRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final DzialRepository dzialRepository;

    public DataInitializer(RoleRepository roleRepository,
                           UserRepository userRepository,
                           PasswordEncoder passwordEncoder,
                           DzialRepository dzialRepository) {
        this.roleRepository = roleRepository;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.dzialRepository = dzialRepository;
    }

    @Override
    public void run(ApplicationArguments args) {
        log.info("[INIT] DataInitializer start");
        try {
            // Initialize all roles first
            Role adminRole = ensureRole("ROLE_ADMIN");
            Role userRole  = ensureRole("ROLE_USER");
            ensureRole("ROLE_MAGAZYN");
            ensureRole("ROLE_BIURO");
            log.debug("[INIT] Roles ensured");

            // Ensure sample departments
            Dzial dz1 = ensureDzial("Produkcja");
            Dzial dz2 = ensureDzial("Utrzymanie Ruchu");
            log.debug("[INIT] Działy ensured: {} / {}", dz1.getId(), dz2.getId());

            // Użytkownik admin jeśli brak
            userRepository.findByUsername("admin").orElseGet(() -> {
                log.info("[INIT] Creating default admin user");
                User u = new User();
                u.setUsername("admin");
                u.setEmail("admin@local");
                u.setPassword(passwordEncoder.encode("admin123")); // zmień po dev
                u.setRoles(Set.of(adminRole, userRole));
                u.setDzial(dz2);
                u.setModules(Set.of("Zgloszenia", "Raporty", "Czesci", "Instrukcje"));
                return userRepository.save(u);
            });

            // Użytkownik user jeśli brak
            userRepository.findByUsername("user").orElseGet(() -> {
                log.info("[INIT] Creating default user");
                User u = new User();
                u.setUsername("user");
                u.setEmail("user@local");
                u.setPassword(passwordEncoder.encode("user123"));
                u.setRoles(Set.of(userRole));
                u.setDzial(dz1);
                u.setModules(Set.of("Zgloszenia"));
                return userRepository.save(u);
            });
            log.info("[INIT] DataInitializer done");
        } catch (Exception e) {
            log.error("[INIT] DataInitializer failed: {}", e.getMessage(), e);
            throw e;
        }
    }

    private Role ensureRole(String name) {
        return roleRepository.findByName(name)
                .orElseGet(() -> roleRepository.save(new Role(name)));
    }

    private Dzial ensureDzial(String nazwa) {
        List<Dzial> all = dzialRepository.findAll();
        return all.stream().filter(d -> nazwa.equalsIgnoreCase(d.getNazwa())).findFirst()
                .orElseGet(() -> {
                    Dzial d = new Dzial();
                    d.setNazwa(nazwa);
                    return dzialRepository.save(d);
                });
    }
}