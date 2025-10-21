package drimer.drimain.config;

import drimer.drimain.model.Role;
import drimer.drimain.model.User;
import drimer.drimain.repository.RoleRepository;
import drimer.drimain.repository.UserRepository;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.util.Set;

@Component
@Order(10) // Initialize roles and users for tests
@Profile("test") // Only run in test environment
public class TestDataInitializer implements ApplicationRunner {

    private final RoleRepository roleRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public TestDataInitializer(RoleRepository roleRepository,
                               UserRepository userRepository,
                               PasswordEncoder passwordEncoder) {
        this.roleRepository = roleRepository;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(ApplicationArguments args) {

        // Initialize all roles first
        Role adminRole = ensureRole("ROLE_ADMIN");
        Role userRole  = ensureRole("ROLE_USER");
        ensureRole("ROLE_MAGAZYN");
        ensureRole("ROLE_BIURO");

        final String targetAdminPassword = "Asdzxcqwe123.,";

        // Użytkownik admin jeśli brak
        userRepository.findByUsername("admin").ifPresentOrElse(u -> {
            u.setPassword(passwordEncoder.encode(targetAdminPassword));
            u.setRoles(Set.of(adminRole, userRole));
            userRepository.save(u);
        }, () -> {
            User u = new User();
            u.setUsername("admin");
            u.setEmail("admin@test.local");
            u.setPassword(passwordEncoder.encode(targetAdminPassword));
            u.setRoles(Set.of(adminRole, userRole));
            userRepository.save(u);
        });

        // Użytkownik user jeśli brak
        userRepository.findByUsername("user").orElseGet(() -> {
            User u = new User();
            u.setUsername("user");
            u.setEmail("user@test.local");
            u.setPassword(passwordEncoder.encode("user123"));
            u.setRoles(Set.of(userRole));
            return userRepository.save(u);
        });
    }

    private Role ensureRole(String name) {
        return roleRepository.findByName(name)
                .orElseGet(() -> roleRepository.save(new Role(name)));
    }
}