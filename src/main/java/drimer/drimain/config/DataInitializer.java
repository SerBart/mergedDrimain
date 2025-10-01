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

import java.util.Set;
import java.util.List;

@Component
@Order(10) // Initialize roles and users
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
        // Initialize all roles first
        Role adminRole = ensureRole("ROLE_ADMIN");
        Role userRole  = ensureRole("ROLE_USER");
        ensureRole("ROLE_MAGAZYN");
        ensureRole("ROLE_BIURO");

        // Ensure sample departments
        Dzial dz1 = ensureDzial("Produkcja");
        Dzial dz2 = ensureDzial("Utrzymanie Ruchu");

        // Użytkownik admin jeśli brak
        userRepository.findByUsername("admin").orElseGet(() -> {
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
            User u = new User();
            u.setUsername("user");
            u.setEmail("user@local");
            u.setPassword(passwordEncoder.encode("user123"));
            u.setRoles(Set.of(userRole));
            u.setDzial(dz1);
            u.setModules(Set.of("Zgloszenia"));
            return userRepository.save(u);
        });
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