package drimer.drimain.config;

import drimer.drimain.model.Dzial;
import drimer.drimain.model.Role;
import drimer.drimain.model.User;
import drimer.drimain.repository.DzialRepository;
import drimer.drimain.repository.RoleRepository;
import drimer.drimain.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.core.env.Environment;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.atLeast;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.ArgumentCaptor;

class DataInitializerTest {

    private RoleRepository roleRepository;
    private UserRepository userRepository;
    private PasswordEncoder passwordEncoder;
    private DzialRepository dzialRepository;
    private Environment environment;

    @BeforeEach
    void setUp() {
        roleRepository = mock(RoleRepository.class);
        userRepository = mock(UserRepository.class);
        passwordEncoder = mock(PasswordEncoder.class);
        dzialRepository = mock(DzialRepository.class);
        environment = mock(Environment.class);

        when(environment.getActiveProfiles()).thenReturn(new String[0]);
        when(passwordEncoder.encode(any())).thenAnswer(invocation -> "encoded:" + invocation.getArgument(0, String.class));

        when(roleRepository.findByName(any())).thenReturn(Optional.empty());
        when(roleRepository.save(any(Role.class))).thenAnswer(invocation -> invocation.getArgument(0, Role.class));

        List<Dzial> dzialy = new ArrayList<>();
        when(dzialRepository.findAll()).thenAnswer(invocation -> new ArrayList<>(dzialy));
        when(dzialRepository.save(any(Dzial.class))).thenAnswer(invocation -> {
            Dzial dzial = invocation.getArgument(0, Dzial.class);
            dzialy.add(dzial);
            return dzial;
        });

        when(userRepository.findByUsername("admin")).thenReturn(Optional.empty());
        when(userRepository.findByUsername("user")).thenReturn(Optional.empty());
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0, User.class));
    }

    @Test
    void shouldCreateDefaultAdminAndUserInLocalProfile() {
        DataInitializer initializer = new DataInitializer(
                roleRepository,
                userRepository,
                passwordEncoder,
                dzialRepository,
                environment
        );
        ReflectionTestUtils.setField(initializer, "adminUsername", "admin");
        ReflectionTestUtils.setField(initializer, "adminPassword", "admin123");
        ReflectionTestUtils.setField(initializer, "adminForceReset", true);

        initializer.run(new DefaultApplicationArguments());

        ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
        verify(userRepository, atLeast(2)).save(userCaptor.capture());

        List<User> savedUsers = userCaptor.getAllValues();
        List<String> usernames = savedUsers.stream()
                .map(User::getUsername)
                .toList();

        assertTrue(usernames.contains("admin"));
        assertTrue(usernames.contains("user"));

        User admin = savedUsers.stream()
                .filter(user -> "admin".equals(user.getUsername()))
                .findFirst()
                .orElseThrow();
        User regularUser = savedUsers.stream()
                .filter(user -> "user".equals(user.getUsername()))
                .findFirst()
                .orElseThrow();

        assertEquals("admin@local", admin.getEmail());
        assertEquals("encoded:admin123", admin.getPassword());
        assertTrue(admin.getRoles().stream().anyMatch(role -> "ROLE_ADMIN".equals(role.getName())));

        assertEquals("user@local", regularUser.getEmail());
        assertEquals("encoded:user123", regularUser.getPassword());
    }
}

