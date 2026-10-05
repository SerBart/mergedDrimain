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
import java.util.Locale;
import java.util.Set;

@Component
@Order(10)
@Slf4j
public class DataInitializer implements ApplicationRunner {

    private static final Set<String> DEFAULT_ADMIN_MODULES = Set.of("Zgloszenia", "Raporty", "Czesci", "Instrukcje");

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

        boolean prodProfile = isProdProfileActive();
        String effectiveAdminUsername = resolveBootstrapAdminUsername();
        String effectiveAdminPassword = resolveBootstrapAdminPassword(prodProfile);
        boolean effectiveAdminForceReset = adminForceReset || !prodProfile;

        Role adminRole = ensureRole("ROLE_ADMIN");
        Role userRole = ensureRole("ROLE_USER");
        ensureRole("ROLE_MAGAZYN");
        ensureRole("ROLE_BIURO");

        ensureDzial("Produkcja");
        Dzial maintenanceDepartment = ensureDzial("Utrzymanie Ruchu");
        ensureDzial("Technologie");

        ensureBootstrapAdmin(effectiveAdminUsername, effectiveAdminPassword, effectiveAdminForceReset, adminRole, userRole, maintenanceDepartment);

        if (!prodProfile) {
            ensureRegularUser(userRole, maintenanceDepartment);
        }
    }

    private void ensureBootstrapAdmin(String username,
                                      String rawPassword,
                                      boolean forceResetPassword,
                                      Role adminRole,
                                      Role userRole,
                                      Dzial dzial) {
        String normalizedUsername = username.trim();
        String bootstrapEmail = buildBootstrapEmail(normalizedUsername);

        userRepository.findByUsername(normalizedUsername).ifPresentOrElse(user -> {
            user.setUsername(normalizedUsername);
            user.setEmail(bootstrapEmail);
            user.setRoles(Set.of(adminRole, userRole));
            user.setDzial(dzial);
            user.setModules(DEFAULT_ADMIN_MODULES);

            if (forceResetPassword && notBlank(rawPassword)) {
                user.setPassword(passwordEncoder.encode(rawPassword));
                log.info("[INIT] Bootstrap admin password synchronized for user {}", normalizedUsername);
            } else {
                log.info("[INIT] Bootstrap admin user {} already exists", normalizedUsername);
            }

            userRepository.save(user);
        }, () -> {
            if (!notBlank(rawPassword)) {
                log.warn("[INIT] Bootstrap admin user {} was not created because password is blank", normalizedUsername);
                return;
            }

            User user = new User();
            user.setUsername(normalizedUsername);
            user.setEmail(bootstrapEmail);
            user.setPassword(passwordEncoder.encode(rawPassword));
            user.setRoles(Set.of(adminRole, userRole));
            user.setDzial(dzial);
            user.setModules(DEFAULT_ADMIN_MODULES);
            userRepository.save(user);

            log.info("[INIT] Created bootstrap admin user {}", normalizedUsername);
        });
    }

    private void ensureRegularUser(Role userRole, Dzial dzial) {
        userRepository.findByUsername("user").ifPresentOrElse(user -> {
            user.setEmail("user@local");
            user.setPassword(passwordEncoder.encode("user123"));
            user.setRoles(Set.of(userRole));
            user.setDzial(dzial);
            if (user.getModules() == null || user.getModules().isEmpty()) {
                user.setModules(Set.of("Zgloszenia", "Raporty"));
            }
            userRepository.save(user);
        }, () -> {
            User user = new User();
            user.setUsername("user");
            user.setEmail("user@local");
            user.setPassword(passwordEncoder.encode("user123"));
            user.setRoles(Set.of(userRole));
            user.setDzial(dzial);
            user.setModules(Set.of("Zgloszenia", "Raporty"));
            userRepository.save(user);
        });
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
        return all.stream()
                .filter(d -> nazwa.equalsIgnoreCase(d.getNazwa()))
                .findFirst()
                .orElseGet(() -> {
                    Dzial d = new Dzial();
                    d.setNazwa(nazwa);
                    return dzialRepository.save(d);
                });
    }

    private String resolveBootstrapAdminUsername() {
        return notBlank(adminUsername) ? adminUsername.trim() : "admin";
    }

    private String resolveBootstrapAdminPassword(boolean prodProfile) {
        if (notBlank(adminPassword)) {
            return adminPassword.trim();
        }
        return prodProfile ? "" : "admin123";
    }

    private String buildBootstrapEmail(String username) {
        String normalized = username == null ? "" : username.trim().toLowerCase(Locale.ROOT);
        if (normalized.isBlank()) {
            return "admin@local";
        }
        return normalized.contains("@") ? normalized : normalized + "@local";
    }

    private boolean notBlank(String value) {
        return value != null && !value.trim().isEmpty();
    }
}


