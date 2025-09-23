package drimer.drimain.config;

import drimer.drimain.model.Role;
import drimer.drimain.model.User;
import drimer.drimain.repository.RoleRepository;
import drimer.drimain.repository.UserRepository;
import org.flywaydb.core.Flyway;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.context.annotation.Conditional;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;

import java.util.Set;

@Component
@Order(10)
// Tylko gdy jest Flyway (prod/dev) i nie w profilu test
@ConditionalOnBean(Flyway.class)
@Profile("!test")
public class DataInitializer implements ApplicationRunner {
    private final RoleRepository roleRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public DataInitializer(RoleRepository roleRepository,
                           UserRepository userRepository,
                           PasswordEncoder passwordEncoder) {
        this.roleRepository = roleRepository;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(ApplicationArguments args) {
        Role adminRole = ensureRole("ROLE_ADMIN");
        Role userRole  = ensureRole("ROLE_USER");
        ensureRole("ROLE_MAGAZYN");
        ensureRole("ROLE_BIURO");

        userRepository.findByUsername("admin").orElseGet(() -> {
            User u = new User();
            u.setUsername("admin");
            u.setPassword(passwordEncoder.encode("admin123"));
            u.setRoles(Set.of(adminRole, userRole));
            return userRepository.save(u);
        });

        userRepository.findByUsername("user").orElseGet(() -> {
            User u = new User();
            u.setUsername("user");
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