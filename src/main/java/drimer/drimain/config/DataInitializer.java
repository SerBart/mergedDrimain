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
import org.springframework.beans.factory.annotation.Value;
import lombok.extern.slf4j.Slf4j;

import java.util.Set;
import java.util.List;
import java.util.Optional;

@Component
@Order(10) // Initialize roles and users
@Slf4j
public class DataInitializer implements ApplicationRunner {

    private final RoleRepository roleRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final DzialRepository dzialRepository;

    @Value("${app.admin.username:admin}")
    private String adminUsername;

    @Value("${app.admin.force-reset:false}")
    private boolean adminForceReset;

    @Value("${app.admin.password:}")
    private String adminPassword;

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

            Optional<User> adminOpt = userRepository.findByUsername(adminUsername);

            if (adminOpt.isPresent()) {
                if (adminForceReset && notBlank(adminPassword)) {
                    log.info("[INIT] Forcing admin password reset");
                    User u = adminOpt.get();
                    u.setPassword(passwordEncoder.encode(adminPassword));
                    // Bezpiecznie nadpisujemy pola bez odczytu LAZY
                    u.setRoles(Set.of(adminRole, userRole));
                    u.setDzial(dz2);
                    u.setModules(Set.of("Zgloszenia", "Raporty", "Czesci", "Instrukcje"));
                    userRepository.save(u);
                } else {
                    log.info("[INIT] Admin exists; no password reset (set app.admin.force-reset=true + app.admin.password to reset)");
                }
            } else {
                if (notBlank(adminPassword)) {
                    log.info("[INIT] Creating admin user {}");
                    User u = new User();
                    u.setUsername(adminUsername);
                    u.setEmail("admin@local");
                    u.setPassword(passwordEncoder.encode(adminPassword));
                    u.setRoles(Set.of(adminRole, userRole));
                    u.setDzial(dz2);
                    u.setModules(Set.of("Zgloszenia", "Raporty", "Czesci", "Instrukcje"));
                    userRepository.save(u);
                } else {
                    log.warn("[INIT] Admin user does not exist and app.admin.password is empty. Skipping admin creation for safety.");
                }
            }

            // Użytkownik 'user' (dev/demo) – utwórz tylko jeśli nie istnieje
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

    private boolean notBlank(String s) {
        return s != null && !s.trim().isEmpty();
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