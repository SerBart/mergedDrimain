package drimer.drimain.config;

import drimer.drimain.model.Dzial;
import drimer.drimain.model.Role;
import drimer.drimain.model.User;
import drimer.drimain.repository.DzialRepository;
import drimer.drimain.repository.RoleRepository;
import drimer.drimain.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.core.env.Environment;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;
import java.util.Set;

@Component
@Order(10)
@Slf4j
public class DataInitializer implements ApplicationRunner {

    private final RoleRepository roleRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final DzialRepository dzialRepository;
    private final Environment environment;

    @Value("${app.admin.username:admin}")
    private String adminUsername;

    @Value("${app.admin.force-reset:true}")
    private boolean adminForceReset;

    @Value("${app.admin.password:admin123}")
    private String adminPassword;

    public DataInitializer(RoleRepository roleRepository,
                           UserRepository userRepository,
                           PasswordEncoder passwordEncoder,
                           DzialRepository dzialRepository,
                           Environment environment) {
        this.roleRepository = roleRepository;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.dzialRepository = dzialRepository;
        this.environment = environment;
    }

    @Override
    public void run(ApplicationArguments args) {
        log.info("[INIT] DataInitializer start");
        try {
            final boolean prodProfile = isProdProfileActive();
            final String effectiveAdminPassword = notBlank(adminPassword)
                    ? adminPassword
                    : (prodProfile ? "" : "admin123");
            final boolean effectiveAdminForceReset = adminForceReset || !prodProfile;

            Role adminRole = ensureRole("ROLE_ADMIN");
            Role userRole = ensureRole("ROLE_USER");
            ensureRole("ROLE_MAGAZYN");
            ensureRole("ROLE_BIURO");
            log.debug("[INIT] Roles ensured");

            Dzial dz1 = ensureDzial("Produkcja");
            Dzial dz2 = ensureDzial("Utrzymanie Ruchu");
            Dzial dz3 = ensureDzial("Technologie");
            log.debug("[INIT] Działy ensured: {} / {} / {}", dz1.getId(), dz2.getId(), dz3.getId());

            Optional<User> adminOpt = userRepository.findByUsername(adminUsername);
            String bootstrapAdminEmail = buildBootstrapEmail(adminUsername);

            if (adminOpt.isPresent()) {
                if (effectiveAdminForceReset && notBlank(effectiveAdminPassword)) {
                    log.info("[INIT] Forcing bootstrap admin password reset for user {}", adminUsername);
                    User u = adminOpt.get();
                    u.setPassword(passwordEncoder.encode(effectiveAdminPassword));
                    u.setRoles(Set.of(adminRole, userRole));
                    u.setDzial(dz2);
                    u.setModules(Set.of("Zgloszenia", "Raporty", "Czesci", "Instrukcje"));
                    userRepository.save(u);
                } else {
                    log.info("[INIT] Admin exists; no password reset (set app.admin.force-reset=true + app.admin.password to reset)");
                }
            } else {
                if (notBlank(effectiveAdminPassword)) {
                    log.info("[INIT] Creating bootstrap admin user {} with email {}", adminUsername, bootstrapAdminEmail);
                    User u = new User();
                    u.setUsername(adminUsername);
                    u.setEmail(bootstrapAdminEmail);
                    u.setPassword(passwordEncoder.encode(effectiveAdminPassword));
                    u.setRoles(Set.of(adminRole, userRole));
                    u.setDzial(dz2);
                    u.setModules(Set.of("Zgloszenia", "Raporty", "Czesci", "Instrukcje"));
                    userRepository.save(u);
                } else {
                    log.warn("[INIT] Admin user does not exist and app.admin.password is empty. Skipping admin creation for safety.");
                }
            }

            userRepository.findByUsername("user").ifPresentOrElse(u -> {
                if (!prodProfile) {
                    u.setPassword(passwordEncoder.encode("user123"));
                    u.setRoles(Set.of(userRole));
                    u.setDzial(dz1);
                    u.setModules(Set.of("Zgloszenia"));
                    userRepository.save(u);
                }
            }, () -> {
                log.info("[INIT] Creating default user");
                User u = new User();
                u.setUsername("user");
                u.setEmail("user@local");
                u.setPassword(passwordEncoder.encode("user123"));
                u.setRoles(Set.of(userRole));
                u.setDzial(dz1);
                u.setModules(Set.of("Zgloszenia"));
                userRepository.save(u);
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

    private String buildBootstrapEmail(String username) {
        if (!notBlank(username)) {
            return "admin@local";
        }
        String normalized = username.trim().toLowerCase();
        return normalized.contains("@") ? normalized : normalized + "@local";
    }

    private boolean isProdProfileActive() {
        for (String profile : environment.getActiveProfiles()) {
            if ("prod".equalsIgnoreCase(profile)) {
                return true;
            }
        }
        return false;
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
