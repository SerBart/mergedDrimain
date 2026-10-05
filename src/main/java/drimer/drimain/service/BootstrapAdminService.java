package drimer.drimain.service;

import drimer.drimain.model.Dzial;
import drimer.drimain.model.Role;
import drimer.drimain.model.User;
import drimer.drimain.repository.DzialRepository;
import drimer.drimain.repository.RoleRepository;
import drimer.drimain.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Locale;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Slf4j
public class BootstrapAdminService {

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final DzialRepository dzialRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.admin.username:admin}")
    private String adminUsername;

    @Value("${app.admin.password:admin123}")
    private String adminPassword;

    @Transactional
    public void ensureBootstrapAdminForLogin(String attemptedUsername, String attemptedPassword) {
        if (!matchesConfiguredBootstrapCredentials(attemptedUsername, attemptedPassword)) {
            return;
        }

        Role adminRole = ensureRole("ROLE_ADMIN");
        Role userRole = ensureRole("ROLE_USER");
        Dzial utrzymanieRuchu = ensureDzial("Utrzymanie Ruchu");
        String targetEmail = chooseBootstrapEmail(adminUsername);

        User user = userRepository.findByUsername(adminUsername).orElseGet(User::new);
        boolean isNewUser = user.getId() == null;

        user.setUsername(adminUsername);
        if (isNewUser || user.getEmail() == null || user.getEmail().isBlank()) {
            user.setEmail(targetEmail);
        }
        user.setPassword(passwordEncoder.encode(adminPassword));
        user.setRoles(Set.of(adminRole, userRole));
        user.setDzial(utrzymanieRuchu);
        user.setModules(Set.of("Zgloszenia", "Raporty", "Czesci", "Instrukcje"));
        userRepository.save(user);

        log.info("[BOOTSTRAP-AUTH] Bootstrap admin {} {} for login flow", adminUsername, isNewUser ? "created" : "synchronized");
    }

    private boolean matchesConfiguredBootstrapCredentials(String attemptedUsername, String attemptedPassword) {
        return notBlank(adminUsername)
                && notBlank(adminPassword)
                && adminUsername.equalsIgnoreCase(trimToEmpty(attemptedUsername))
                && adminPassword.equals(attemptedPassword);
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

    private String chooseBootstrapEmail(String username) {
        String base = buildBootstrapEmail(username);
        var existing = userRepository.findByEmail(base);
        if (existing.isEmpty() || username.equalsIgnoreCase(existing.get().getUsername())) {
            return base;
        }
        return username.toLowerCase(Locale.ROOT) + "+bootstrap@local";
    }

    private String buildBootstrapEmail(String username) {
        String normalized = trimToEmpty(username).toLowerCase(Locale.ROOT);
        if (normalized.isBlank()) {
            return "admin@local";
        }
        return normalized.contains("@") ? normalized : normalized + "@local";
    }

    private boolean notBlank(String value) {
        return value != null && !value.trim().isEmpty();
    }

    private String trimToEmpty(String value) {
        return value == null ? "" : value.trim();
    }
}

